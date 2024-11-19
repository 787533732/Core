module bpu 
#(
    parameter SUPPORT_BRANCH_PREDICTION = 1  ,
    parameter GSHARE_ENABLE             = 1  ,
    parameter PHT_ENABLE                = 1  ,
    parameter RAS_ENABLE                = 1  ,
    parameter NUM_PHT_ENTRIES           = 512,//4KB
    parameter NUM_PHT_ENTRIES_W         = 9  ,
    parameter NUM_RAS_ENTRIES           = 8  ,
    parameter NUM_RAS_ENTRIES_W         = 3  ,
    parameter NUM_BTB_ENTRIES           = 32 ,
    parameter NUM_BTB_ENTRIES_W         = 5
) 
(
    input   wire                clk_i                ,
    input   wire                rstn_i               ,
    //在执行阶段得到实际的跳转信息，发送到issue确认后，输入用于分支预测学习
    input   wire                branch_request_i     ,//分支预测错误标志
    input   wire                branch_is_taken_i    ,//执行阶段真实跳转情况
    input   wire                branch_is_not_taken_i,
    input   wire                branch_is_call_i     ,//提交阶段最终确认的指令类型
    input   wire                branch_is_ret_i      ,
    input   wire                branch_is_jmp_i      ,
    input   wire [31:0]         branch_source_i      ,//发生分支的PC
    input   wire [31:0]         branch_pc_i          ,//目标地址
    //当前PC
    input   wire [31:0]         pc_f_i               ,
    input   wire                pc_accept_i          ,//取指模块就绪
    //to fetch
    output  wire [31:0]         next_pc_f_o          ,//预测的下一条PC
    output  wire [1:0]          next_taken_f_o        //预测的跳转方向(00不跳01低位跳10高位跳)
);
    localparam RAS_INVALID = 32'h0000_0001;

generate
    if(SUPPORT_BRANCH_PREDICTION) begin
//-----------------------------------------------------------------
// Branch prediction (Gshare+PHT,RAS,BTB)其中RAS用来预测return
//-----------------------------------------------------------------
    //最终的分支预测结果
    wire        pred_taken_w;
    wire        pred_ntaken_w;
    //from BTB
    wire        btb_valid_w;
    wire        btb_upper_w;
    wire        btb_is_call_w;//BTB记录下的类型
    wire        btb_is_ret_w;
//-----------------------------------------------------------------
//Real RAS 
//-----------------------------------------------------------------
    //真实指针
    reg [NUM_RAS_ENTRIES_W-1:0]ras_index_real_q;
    reg [NUM_RAS_ENTRIES_W-1:0]ras_index_real_r;
    always @(*) begin
        ras_index_real_r <= ras_index_real_q;
        if(branch_request_i & branch_is_call_i)//第一次遇到肯定会错误
            ras_index_real_r <= ras_index_real_q + 1;//call指令压入一条地址，指针+1
        else if(branch_request_i & branch_is_ret_i)
            ras_index_real_r <= ras_index_real_q - 1;//return指令弹出一条地址，指针-1
    end
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            ras_index_real_q <= {NUM_PHT_ENTRIES_W{1'b0}};
        else
            ras_index_real_q <= ras_index_real_r;
    end
//-----------------------------------------------------------------
//Speculative RAS
//-----------------------------------------------------------------
    //预测的RAS指针
    reg  [NUM_RAS_ENTRIES_W-1:0]ras_index_q;
    reg  [NUM_RAS_ENTRIES_W-1:0]ras_index_r;
    reg  [31:0] ras_stack_q[NUM_RAS_ENTRIES-1:0];//RAS宽度32bit深度8
    //对跳转地址和指令进行预测
    wire [31:0] ras_pc_pred_w;
    wire        ras_call_pred_w;
    wire        ras_ret_pred_w;

    always @(*) begin
        ras_index_r = ras_index_q;
        //预测错误
        if(branch_request_i & branch_is_call_i)
            ras_index_r = ras_index_real_q + 1;//用真实指针进行恢复
        else if(branch_request_i & branch_is_ret_i)
            ras_index_r = ras_index_real_q - 1;
        //预测call/return指令
        else if(ras_call_pred_w & pc_accept_i)
            ras_index_r = ras_index_q + 1;
        else if(ras_ret_pred_w & pc_accept_i)
            ras_index_r = ras_index_q - 1;      
    end

    integer i3;
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            for(i3 = 0;i3 < NUM_RAS_ENTRIES; i3 = i3 + 1) begin
                ras_stack_q[i3] <= RAS_INVALID;
            end
            ras_index_q <= {NUM_RAS_ENTRIES_W{1'b0}};
        end
        //预测错误的call指令
        else if(branch_request_i & branch_is_call_i) begin
            ras_stack_q[ras_index_r] <= branch_source_i + 32'd4;//把正确地址写入堆栈
            ras_index_q              <= ras_index_r;
        end
        //预测正确的call指令
        else if(ras_call_pred_w & pc_accept_i) begin//pc_f_i为低32bit地址，如果是高32bit指令发生跳转，pc_f_i需要+8
            ras_stack_q[ras_index_r] <= (btb_upper_w ? (pc_f_i | 32'd4) : pc_f_i) + 32'd4;
            ras_index_q              <= ras_index_r;
        end
        else if((branch_request_i & branch_is_ret_i) || (ras_ret_pred_w & pc_accept_i))//ret指针下移就行，不用清除数据
            ras_index_q              <= ras_index_r; 
    end
    assign ras_pc_pred_w   = ras_stack_q[ras_index_q];
    //btb找得到该指令并且堆栈里地址有效
    assign ras_call_pred_w = RAS_ENABLE & (btb_valid_w & btb_is_call_w) & ~ras_pc_pred_w[0];
    assign ras_ret_pred_w  = RAS_ENABLE & (btb_valid_w & btb_is_ret_w)  & ~ras_pc_pred_w[0];
//----------------------------------------------------------------------------------------------------------------------------------
//Gshare+PHT（预测失败恢复方法：提交阶段修复法）
//----------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------
//Real GHR(因为顺序执行，所以可以在执行时根据跳转情况更新)
//-----------------------------------------------------------------
    reg [NUM_PHT_ENTRIES_W-1:0] global_history_real_q;
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) 
            global_history_real_q <= {NUM_PHT_ENTRIES_W{1'b0}};
        else if(branch_is_taken_i || branch_is_not_taken_i)//从低位更新GHR，舍弃最高位记录
            global_history_real_q <= {global_history_real_q[NUM_PHT_ENTRIES_W-2:0],branch_is_taken_i};
    end
//-----------------------------------------------------------------
//Speculative GHR(在取指阶段根据分支预测结果更新)
//-----------------------------------------------------------------
    reg [NUM_PHT_ENTRIES_W-1:0] global_history_q;
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) 
            global_history_q <= {NUM_PHT_ENTRIES_W{1'b0}};
        else if(branch_request_i)//预测错误时，用真实全局历史进行覆盖
            global_history_q <= {global_history_real_q[NUM_PHT_ENTRIES_W-2:0],branch_is_taken_i};
        else if(pred_taken_w || pred_ntaken_w)//得到预测结果则更新GHR
            global_history_q <= {global_history_q[NUM_PHT_ENTRIES_W-2:0],pred_taken_w};
    end
//-----------------------------------------------------------------
//PHT(在分支指令执行得到结果后对饱和计数器进行更新)
//-----------------------------------------------------------------
    //gshare
    wire [NUM_PHT_ENTRIES_W-1:0] gshare_wr_entry_w = (branch_request_i ? global_history_real_q : global_history_q) 
                                                   ^ branch_source_i[2+NUM_PHT_ENTRIES_W-1:2];
    wire [NUM_PHT_ENTRIES_W-1:0] gshare_rd_entry_w = global_history_q ^ {pc_f_i[3+NUM_PHT_ENTRIES_W-2:3],btb_upper_w};//根据当前取指的PC进行分支预测
    //用gshare算法得到的地址寻值2bit饱和计数器
    reg [1:0] pht_sat_q [NUM_PHT_ENTRIES-1:0];
    //寻值饱和计数器的地址
    wire [NUM_PHT_ENTRIES_W-1:0] pht_wr_entry_w = GSHARE_ENABLE ? gshare_wr_entry_w : branch_source_i[2+NUM_PHT_ENTRIES_W-1:2];//训练
    wire [NUM_PHT_ENTRIES_W-1:0] pht_rd_entry_w = GSHARE_ENABLE ? gshare_rd_entry_w : {pc_f_i[3+NUM_PHT_ENTRIES_W-2:3],btb_upper_w};//预测a

    integer i4;
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            for(i4 = 0;i4 < NUM_PHT_ENTRIES;i4 = i4 + 1) begin
                pht_sat_q[i4] <= 2'd0;//初始化为强不跳转状态
            end       
        end else if(branch_is_taken_i && pht_sat_q[pht_wr_entry_w] < 2'd3) begin
                pht_sat_q[pht_wr_entry_w] <= pht_sat_q[pht_wr_entry_w] + 2'd1;//指令发生跳转时，往跳转方向转换
        end else if(branch_is_not_taken_i && pht_sat_q[pht_wr_entry_w] > 2'd0)
                pht_sat_q[pht_wr_entry_w] <= pht_sat_q[pht_wr_entry_w] - 2'd1;//指令不跳转时，往不跳转方向转换          
    end
    //预测的结果
    wire pht_predict_taken_w = PHT_ENABLE && (pht_sat_q[pht_rd_entry_w] >= 2'd2);
//----------------------------------------------------------------------------------------------------------------------------------
//Branch Target Buffer（使用直接映射）
//----------------------------------------------------------------------------------------------------------------------------------
    //BTB存放每个PC对应跳转目标地址，以及每个PC对应的指令类型
    reg             btb_valid_r;//Valid Bit
    reg [31:0]      btb_pc_q[NUM_BTB_ENTRIES-1:0];//Branch Instruction Address
    reg [31:0]      btb_target_q[NUM_BTB_ENTRIES-1:0];//Branch Target Address
    reg             btb_is_call_q[NUM_BTB_ENTRIES-1:0];//BTB中增加的一项用于标记分支指令类型
    reg             btb_is_ret_q[NUM_BTB_ENTRIES-1:0];
    reg             btb_is_jmp_q[NUM_BTB_ENTRIES-1:0];

    reg [31:0]      btb_next_pc_r;//跳转目标地址
    reg             btb_is_call_r;
    reg             btb_is_ret_r;
    reg             btb_is_jmp_r;
    reg             btb_upper_r;//一次取出64bit，pc[2]=1的是高32bit的指令
    //read
    integer i0;
    always @(*) begin
        btb_valid_r   = 1'b0;
        btb_upper_r   = 1'b0;
        btb_is_call_r = 1'b0;
        btb_is_ret_r  = 1'b0;
        btb_is_jmp_r  = 1'b0;
        btb_next_pc_r = {pc_f_i[31:3], 3'b0} + 32'd8;//！如果BTB缺失！，继续顺序取指
        for(i0 = 0;i0 < NUM_BTB_ENTRIES; i0 = i0 + 1) begin
            if(btb_pc_q[i0] == pc_f_i) begin
                btb_valid_r   = 1'b1;
                btb_upper_r   = pc_f_i[2];
                btb_is_call_r = btb_is_call_q[i0];
                btb_is_ret_r  = btb_is_ret_q[i0];
                btb_is_jmp_r  = btb_is_jmp_q[i0];
                btb_next_pc_r = btb_target_q[i0];
            end        
        end
        //低32bit遍历不成功，遍历高32bit
        if(~btb_valid_r && ~pc_f_i[2]) begin
            for(i0 = 0;i0 < NUM_BTB_ENTRIES; i0 = i0 + 1) begin
                if(btb_pc_q[i0] == (pc_f_i | 32'd4)) begin//加个偏移量遍历
                    btb_valid_r   = 1'b1;
                    btb_upper_r   = 1'b1;
                    btb_is_call_r = btb_is_call_q[i0];
                    btb_is_ret_r  = btb_is_ret_q[i0];
                    btb_is_jmp_r  = btb_is_jmp_q[i0];
                    btb_next_pc_r = btb_target_q[i0];
                end        
            end 
        end
    end
        
    reg [NUM_BTB_ENTRIES_W-1:0] btb_wr_entry_r;
    wire[NUM_BTB_ENTRIES_W-1:0] btb_wr_alloc_w;
    reg btb_hit_r;
    reg btb_miss_r;
    integer i1;
    always @(*) begin
        btb_hit_r      = 1'b0;
        btb_miss_r     = 1'b0;
        btb_wr_entry_r = {NUM_BTB_ENTRIES_W{1'b0}}; 
        //预测错误判断hit/miss来更新BTB
        if(branch_request_i) begin
            for(i1 = 0;i1 < NUM_BTB_ENTRIES;i1 = i1 + 1) begin
                if(btb_pc_q[i1] == branch_source_i) begin//
                    btb_hit_r      = 1'b1;
                    btb_wr_entry_r = i1;//根据指令执行时的结果来更新BTB
                end
            end
            btb_miss_r = ~btb_hit_r;
        end
    end
    //write
    integer i2;
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            for(i2 = 0;i2 < NUM_BTB_ENTRIES;i2 = i2 +1) begin
                btb_pc_q[i2]      <= 32'b0;
                btb_target_q[i2]  <= 32'b0;
                btb_is_call_q[i2] <= 1'b0;
                btb_is_ret_q[i2]  <= 1'b0;
                btb_is_jmp_q[i2]  <= 1'b0;
            end
        end 
        //hit,根据指令退休时的结果来更新BTB
        else if(btb_hit_r) begin
            btb_pc_q[btb_wr_entry_r] <= branch_source_i;
            if(branch_is_taken_i) begin//需要跳转才保存跳转信息
                btb_target_q[btb_wr_entry_r]  <= branch_pc_i;
                btb_is_call_q[btb_wr_entry_r] <= branch_is_call_i;
                btb_is_ret_q[btb_wr_entry_r]  <= branch_is_ret_i;
                btb_is_jmp_q[btb_wr_entry_r]  <= branch_is_jmp_i;
            end
        end 
        //Miss时，采用cache随机替换策略
        else if(btb_miss_r) begin
            btb_pc_q[btb_wr_alloc_w]      <= branch_source_i;
            btb_target_q[btb_wr_alloc_w]  <= branch_pc_i;
            btb_is_call_q[btb_wr_alloc_w] <= branch_is_call_i;
            btb_is_ret_q[btb_wr_alloc_w]  <= branch_is_ret_i;
            btb_is_jmp_q[btb_wr_alloc_w]  <= branch_is_jmp_i;
        end
    end
    //用于产生伪随机数
    bpu_lfsr
    #(
        .DEPTH          (NUM_BTB_ENTRIES  ),       
        .ADDR_W         (NUM_BTB_ENTRIES_W)      
    )
    bpu
    (
        .clk_i          (clk_i            ),
        .rstn_i         (rstn_i           ),
        .alloc_i        (btb_miss_r       ),
        .alloc_entry_o  (btb_wr_alloc_w   )
    );
//-----------------------------------------------------------------
// Outputs
//-----------------------------------------------------------------
    assign btb_valid_w    = btb_valid_r;
    assign btb_upper_w    = btb_upper_r;
    assign btb_is_call_w  = btb_is_call_r;
    assign btb_is_ret_w   = btb_is_ret_r;
//预测是基于btb的，因此在程序刚开始运行时，btb空白，会预测不跳
//当btb对此时的PC有记录时，再判断：1.如果是条件跳转，用pht预测2.如果是无条件直接跳转，用btb的记录预测3.如果是return,用RAS预测
    assign next_taken_f_o = (btb_valid_w &(pht_predict_taken_w | btb_is_jmp_r | ras_ret_pred_w)) ?
                            (pc_f_i[2] ? {btb_upper_r, 1'b0} : {btb_upper_r, ~btb_upper_r}) : 2'b0;
    assign next_pc_f_o    = ras_ret_pred_w ? ras_pc_pred_w ://预测为Return指令，把RAS地址作为下个PC
                            (pht_predict_taken_w | btb_is_jmp_r) ? btb_next_pc_r ://普通的需要跳转指令用BTB预测跳转地址
                            {pc_f_i[31:3],3'b0} + 32'd8;

    //BTB命中为预测前提
    assign pred_taken_w   = btb_valid_w &(pht_predict_taken_w | btb_is_jmp_r | ras_ret_pred_w) & pc_accept_i;
    assign pred_ntaken_w  = btb_valid_w & ~pred_taken_w & pc_accept_i;
end
//--------------------------------------------------------
//No branch prediction 
//--------------------------------------------------------
    else begin
        assign next_pc_f_o    = {pc_f_i[31:3],3'b0} + 32'd8;//默认不跳转，PC+8
        assign next_taken_f_o = 2'b0;
    end
endgenerate

endmodule

module bpu_lfsr//用于产生伪随机数
#(
    parameter DEPTH         = 32      ,
    parameter ADDR_W        = 5       ,
    parameter INITIAL_VALUE = 16'h0001,
    parameter TAP_VALUE     = 16'hb400
)
(
    input   wire                clk_i        ,
    input   wire                rstn_i       ,
    input   wire                alloc_i      ,

    output  wire [ADDR_W-1:0]   alloc_entry_o
);
    reg [15:0] lfsr_q;

    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            lfsr_q <= INITIAL_VALUE;
        else if(alloc_i) begin
            if(lfsr_q[0])
                lfsr_q <= {1'b0, lfsr_q[15:1]} ^ TAP_VALUE;
            else
                lfsr_q <= {1'b0, lfsr_q[15:1]};
        end
    end

    assign alloc_entry_o = lfsr_q[ADDR_W-1:0];

endmodule


