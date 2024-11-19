`include "../core/define.v"
//将npc预测下个时钟的pc打一拍后给npc，同时用这个PC取指
module fetch 
#(
    parameter   SUPPORT_MMU = 0   
)
(
    input   wire            clk_i               ,
    input   wire            rstn_i              ,
    input   wire            fetch_accept_i      ,//指令被预译码模块接受
    input   wire            fetch_invalidate_i  ,
    input   wire            branch_request_i    ,//issue发现分支预测错误
    input   wire [31:0]     branch_pc_i         ,//预测错误回到原来的PC
    input   wire [ 1:0]     branch_priv_i       ,
    //from npc 
    input   wire [31:0]     next_pc_f_i         ,//分支预测得到下个时钟的PC
    input   wire [ 1:0]     next_taken_f_i      ,//分支预测得到的跳转方向
    //i-cache 
    input   wire            icache_accept_i     ,
    input   wire [63:0]     icache_inst_i       ,
    input   wire            icache_valid_i      ,
    input   wire            icache_error_i      ,
    input   wire            icache_page_fault_i ,
    output  wire            icache_rd_o         ,        
    output  wire [31:0]     icache_pc_o         ,
    output  wire [ 1:0]     icache_priv_o       ,
    output  wire            icache_flush_o      ,
    output  wire            icache_invalidate_o ,//0
    //to decode 
    output  wire [63:0]     fetch_instr_o       ,
    output  wire            fetch_valid_o       ,
    output  wire            fetch_fault_page_o  ,
    output  wire            fetch_fault_fetch_o ,
    output  wire [ 1:0]     fetch_pred_branch_o ,
    output  wire [31:0]     fetch_pc_o          ,//发起取指请求的PC         
    //to npc 
    output  wire [31:0]     pc_f_o              ,
    output  wire            pc_accept_o 
);     
    reg  active_q;
    wire icache_busy_w;
    wire stall_w;

    reg         branch_q;
    reg  [31:0] branch_pc_q;
    reg  [1:0]  branch_priv_q;
    wire        branch_w;
    wire [31:0] branch_pc_w;
    wire [1:0]  branch_priv_w;

generate
    if(SUPPORT_MMU) begin
    end 
    else begin//CSR异常或分支预测错误恢复
        assign branch_w      = branch_q || branch_request_i;
        assign branch_pc_w   = (branch_q & !branch_request_i) ? branch_pc_q   : branch_pc_i;
        assign branch_priv_w = `PRIV_MACHINE; // don't care
        always @ (posedge clk_i or negedge rstn_i)
        if (!rstn_i)
        begin
            branch_q       <= 1'b0;
            branch_pc_q    <= 32'b0;
        end
        else if (branch_request_i && (icache_busy_w || !active_q))
        begin
            branch_q       <= branch_w;
            branch_pc_q    <= branch_pc_w;
        end
        else if (~icache_busy_w)
        begin
            branch_q       <= 1'b0;
            branch_pc_q    <= 32'b0;
        end
    end
endgenerate
//-------------------------------------------------------------
//激活信号(MMU模式)
//-------------------------------------------------------------
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            active_q <= 1'b0;
        else if(SUPPORT_MMU && branch_w && stall_w)//分支预测错误
            active_q <= 1'b1;
        else if (!SUPPORT_MMU && branch_w)
            active_q <= 1'b1;
    end
//-------------------------------------------------------------
//暂停信号
//-------------------------------------------------------------
    //暂停信号(预译码模块未准备好|icache busy)
    assign stall_w = !fetch_accept_i || icache_busy_w || !icache_accept_i;
    reg stall_q;
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            stall_q <= 1'b0;
        else
            stall_q <= stall_w;
    end
//-------------------------------------------------------------
//Icache取指使能
//-------------------------------------------------------------
    reg icache_fetch_q;

    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            icache_fetch_q <= 1'b0;
        else if(icache_rd_o && icache_accept_i)
            icache_fetch_q <= 1'b1;
        else if(icache_valid_i)//取指完成
            icache_fetch_q <= 1'b0;
    end
    //第一级流水线寄存器，生成从Icache取指的pc
    reg [31:0]pc_f_q;
    reg [31:0]pc_d_q;
    reg [1:0] pred_d_q;
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            pc_f_q <= 32'b0;
        else if (!SUPPORT_MMU && (stall_w || !active_q || stall_q) && branch_w)
            pc_f_q  <= branch_pc_w;
        // NPC
        else if (!stall_w)
            pc_f_q  <= next_pc_f_i;
    end

    wire [31:0] icache_pc_w;
    wire [1:0]  icache_priv_w;
    wire        fetch_resp_drop_w;

    assign icache_pc_w       = (branch_w & ~stall_q) ? branch_pc_w : pc_f_q;
    assign icache_priv_w     = `PRIV_MACHINE; // Don't care
    assign fetch_resp_drop_w = branch_w;

    //上一次取指地址(pc打一拍)
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            pc_d_q <= 32'h0;
        else if(icache_rd_o && icache_accept_i)
            pc_d_q <= icache_pc_w;
    end
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            pred_d_q <= 2'b0;
        else if(icache_rd_o && icache_accept_i)
            pred_d_q <= next_taken_f_i;
        else if(icache_valid_i)
            pred_d_q <= 2'b0;
    end

//output to icache
    assign icache_busy_w       = icache_fetch_q & !icache_valid_i;
    assign icache_rd_o         = active_q & !icache_busy_w & fetch_accept_i;
    assign icache_pc_o         = {icache_pc_w[31:3], 3'b0};
    assign icache_priv_o       = icache_priv_w;
    assign icache_flush_o      = fetch_invalidate_i;
    assign icache_invalidate_o = 1'b0;
   
//预译码模块的反压，skid_buffer保存数据
    reg [99:0] skid_buffer_q;
    reg        skid_valid_q;
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            skid_buffer_q <= 100'b0;
            skid_valid_q  <= 1'b0;
        end else if(fetch_valid_o && !fetch_accept_i) begin//预译码模块未准备好，把数据暂存入buffer
            skid_buffer_q <= {fetch_fault_page_o,fetch_fault_fetch_o,fetch_pred_branch_o,fetch_pc_o,fetch_instr_o};
            skid_valid_q  <= 1'b1;
        end else begin
            skid_buffer_q <= 100'b0;
            skid_valid_q  <= 1'b0;  
        end

    end
    //skid buffer中有数据时优先读buffer中的数据
    assign fetch_fault_page_o  = skid_valid_q ? skid_buffer_q[99]    : icache_error_i;
    assign fetch_fault_fetch_o = skid_valid_q ? skid_buffer_q[98]    : icache_page_fault_i;
    assign fetch_pred_branch_o = skid_valid_q ? skid_buffer_q[97:96] : pred_d_q;
    assign fetch_pc_o          = skid_valid_q ? skid_buffer_q[95:64] : {pc_d_q[31:3],3'b0};
    assign fetch_instr_o       = skid_valid_q ? skid_buffer_q[63:0]  : icache_inst_i;
    assign fetch_valid_o       = (skid_valid_q || icache_valid_i) && !fetch_resp_drop_w;
    assign pc_f_o              = icache_pc_w;
    assign pc_accept_o         = !stall_w;

endmodule