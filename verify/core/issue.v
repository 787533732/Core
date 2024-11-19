`include "../core/define.v"
module issue 
#(
    parameter SUPPORT_MULDIV        = 1 ,
    parameter SUPPORT_DUAL_ISSUE    = 1 ,
    parameter SUPPORT_LOAD_BYPASS   = 1 ,
    parameter SUPPORT_MUL_BYPASS    = 1 
)
(
    input   wire                clk_i                           ,
    input   wire                rstn_i                          ,
    //from frontend(decode)     
    input   wire [31:0]         fetch0_instr_i                  ,
    input   wire                fetch0_valid_i                  ,
    input   wire [31:0]         fetch0_pc_i                     ,
    input   wire                fetch0_fault_fetch_i            ,
    input   wire                fetch0_fault_page_i             ,
    input   wire                fetch0_instr_invalid_i          ,
    input   wire                fetch0_instr_exec_i             ,
    input   wire                fetch0_instr_lsu_i              ,
    input   wire                fetch0_instr_branch_i           ,
    input   wire                fetch0_instr_mul_i              ,
    input   wire                fetch0_instr_div_i              ,
    input   wire                fetch0_instr_csr_i              ,
    input   wire                fetch0_instr_rs1_valid_i        ,
    input   wire                fetch0_instr_rs2_valid_i        ,
    input   wire                fetch0_instr_rd_valid_i         ,
    input   wire [31:0]         fetch1_instr_i                  ,
    input   wire                fetch1_valid_i                  ,
    input   wire [31:0]         fetch1_pc_i                     ,
    input   wire                fetch1_fault_fetch_i            ,
    input   wire                fetch1_fault_page_i             ,
    input   wire                fetch1_instr_invalid_i          ,
    input   wire                fetch1_instr_exec_i             ,
    input   wire                fetch1_instr_lsu_i              ,
    input   wire                fetch1_instr_branch_i           ,
    input   wire                fetch1_instr_mul_i              ,
    input   wire                fetch1_instr_div_i              ,
    input   wire                fetch1_instr_csr_i              ,
    input   wire                fetch1_instr_rs1_valid_i        ,
    input   wire                fetch1_instr_rs2_valid_i        ,
    input   wire                fetch1_instr_rd_valid_i         ,
    //from exec0 
    input   wire [31:0]         writeback_exec0_value_i         ,   
    input   wire                branch_exec0_request_i          ,
    input   wire                branch_exec0_is_taken_i         ,
    input   wire                branch_exec0_is_not_taken_i     ,
    input   wire [31:0]         branch_exec0_pc_i               ,
    input   wire [31:0]         branch_exec0_source_i           ,
    input   wire                branch_exec0_is_call_i          ,
    input   wire                branch_exec0_is_ret_i           ,
    input   wire                branch_exec0_is_jmp_i           ,
    input   wire                branch_d_exec0_request_i        ,
    input   wire [31:0]         branch_d_exec0_pc_i             ,
    input   wire [ 1:0]         branch_d_exec0_priv_i           ,
    //from exec1    
    input   wire [31:0]         writeback_exec1_value_i         ,
    input   wire                branch_exec1_request_i          ,
    input   wire                branch_exec1_is_taken_i         ,
    input   wire                branch_exec1_is_not_taken_i     ,
    input   wire [31:0]         branch_exec1_pc_i               ,
    input   wire [31:0]         branch_exec1_source_i           ,
    input   wire                branch_exec1_is_call_i          ,
    input   wire                branch_exec1_is_ret_i           ,
    input   wire                branch_exec1_is_jmp_i           ,
    input   wire                branch_d_exec1_request_i        ,//执行阶段确认
    input   wire [31:0]         branch_d_exec1_pc_i             ,
    input   wire [ 1:0]         branch_d_exec1_priv_i           ,
    //from CSR  
    input   wire                branch_csr_request_i            ,
    input   wire [31:0]         branch_csr_pc_i                 ,
    input   wire [ 1:0]         branch_csr_priv_i               ,
    //bypass data 
    input   wire [31:0]         writeback_mul_value_i           ,
    input   wire                writeback_div_valid_i           ,
    input   wire [31:0]         writeback_div_value_i           ,  
    input   wire                writeback_mem_valid_i           ,
    input   wire [31:0]         writeback_mem_value_i           ,
    input   wire [ 5:0]         writeback_mem_exception_i       ,

    input   wire [31:0]         csr_result_value_e1_i           ,    
    input   wire                csr_result_write_e1_i           ,    
    input   wire [31:0]         csr_result_wdata_e1_i           ,    
    input   wire [ 5:0]         csr_result_exception_e1_i       ,
    input   wire                lsu_stall_i                     ,
    input   wire                take_interrupt_i                ,  
//*********************************to frontend*******************************//
//branch_info_request是执行阶段确认后的分支结果,为了准确更新分支预测器，有1～2cycle延迟。
//branch_request是发现取指错误，马上让前级更新纠错，为了迅速减少性能损失。无延迟。
    //to fetch/decode
    output  wire                fetch0_accept_o                 ,
    output  wire                fetch1_accept_o                 ,
    output  wire                branch_request_o                , 
    output  wire [31:0]         branch_pc_o                     ,
    output  wire [ 1:0]         branch_priv_o                   ,
    //to npc用于分支预测学习    
    output  wire                branch_info_request_o           ,
    output  wire                branch_info_is_taken_o          ,
    output  wire                branch_info_is_not_taken_o      ,
    output  wire                branch_info_is_call_o           ,
    output  wire                branch_info_is_ret_o            ,
    output  wire                branch_info_is_jmp_o            ,
    output  wire [31:0]         branch_info_source_o            ,
    output  wire [31:0]         branch_info_pc_o                ,
    
    output  wire                div_opcode_valid_o              ,
    //把预译码模块的信息进一步译码，传到执行模块，组合逻辑无延迟
    output  wire                exec0_opcode_valid_o            ,
    output  wire [31:0]         opcode0_opcode_o                ,
    output  wire [31:0]         opcode0_pc_o                    ,
    output  wire                opcode0_invalid_o               ,
    output  wire [ 4:0]         opcode0_rd_idx_o                ,
    output  wire [ 4:0]         opcode0_ra_idx_o                ,
    output  wire [ 4:0]         opcode0_rb_idx_o                ,
    output  wire [31:0]         opcode0_ra_operand_o            ,//数据捕捉型
    output  wire [31:0]         opcode0_rb_operand_o            ,
    output  wire                exec0_hold_o                    ,
    output  wire                exec1_opcode_valid_o            ,
    output  wire [31:0]         opcode1_opcode_o                ,
    output  wire [31:0]         opcode1_pc_o                    ,
    output  wire                opcode1_invalid_o               ,
    output  wire [ 4:0]         opcode1_rd_idx_o                ,
    output  wire [ 4:0]         opcode1_ra_idx_o                ,
    output  wire [ 4:0]         opcode1_rb_idx_o                ,
    output  wire [31:0]         opcode1_ra_operand_o            ,
    output  wire [31:0]         opcode1_rb_operand_o            ,
    output  wire                exec1_hold_o                    ,
    //to LSU（无延迟
    output  wire                lsu_opcode_valid_o              ,    
    output  wire [31:0]         lsu_opcode_opcode_o             ,
    output  wire [31:0]         lsu_opcode_ra_operand_o         ,
    output  wire [31:0]         lsu_opcode_rb_operand_o         ,
    //to MUL 
    output  wire                mul_opcode_valid_o              ,   
    output  wire [31:0]         mul_opcode_opcode_o             ,
    output  wire [31:0]         mul_opcode_ra_operand_o         ,
    output  wire [31:0]         mul_opcode_rb_operand_o         ,
    output  wire                mul_hold_o                      ,
    //to CSR  
    output  wire                csr_opcode_valid_o              ,  
    output  wire [31:0]         csr_opcode_opcode_o             ,
    output  wire [31:0]         csr_opcode_pc_o                 ,
    output  wire [ 4:0]         csr_opcode_rd_idx_o             ,
    output  wire [ 4:0]         csr_opcode_ra_idx_o             ,
    output  wire [ 4:0]         csr_opcode_rb_idx_o             ,
    output  wire [31:0]         csr_opcode_ra_operand_o         ,
    output  wire [31:0]         csr_opcode_rb_operand_o         ,
    output  wire                csr_opcode_invalid_o            ,
    output  wire                csr_writeback_write_o           ,
    output  wire [11:0]         csr_writeback_waddr_o           ,
    output  wire [31:0]         csr_writeback_wdata_o           ,
    output  wire [ 5:0]         csr_writeback_exception_o       ,
    output  wire [31:0]         csr_writeback_exception_pc_o    ,
    output  wire [31:0]         csr_writeback_exception_addr_o  , 


    output  wire                interrupt_inhibit_o         

);

    wire enable_dual_issue_w = SUPPORT_DUAL_ISSUE;
    wire enable_muldiv_w     = SUPPORT_MULDIV;
    wire enable_mul_bypass_W = SUPPORT_MUL_BYPASS;

    wire stall_w;
    wire squash_w;//中断？
//-------------------------------------------------------------
// 根据exec计算结果确认PC是否正确
//-------------------------------------------------------------
    reg [31:0] pc_x_q;
    reg [ 1:0] priv_x_q;
    wire       single_issue_w;
    wire       dual_issue_w;

    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            pc_x_q <= 32'h0;
        else if(branch_csr_request_i)
            pc_x_q <= branch_csr_pc_i;
        else if(branch_d_exec1_request_i)
            pc_x_q <= branch_d_exec1_pc_i;
        else if(branch_d_exec0_request_i)
            pc_x_q <= branch_d_exec0_pc_i;
        else if(dual_issue_w)
            pc_x_q <= pc_x_q + 32'd8;
        else if(single_issue_w)
            pc_x_q <= pc_x_q + 32'd4;
    end

    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            priv_x_q <= `PRIV_MACHINE;
        else if(branch_csr_request_i)
            priv_x_q <= branch_csr_priv_i;
    end

/*------------------------选择/仲裁电路------------------------*/
    reg mispredicted_r;
    reg slot0_valid_r;
    reg slot1_valid_r;

    always @(*) begin
        mispredicted_r = 1'b0;
        slot0_valid_r  = 1'b0;
        slot1_valid_r  = 1'b0;
        //CSR跳转
        if(branch_csr_request_i || squash_w) begin
            slot0_valid_r = 1'b0;
            slot1_valid_r = 1'b0;
        end 
        else if(fetch0_valid_i && {fetch0_pc_i[31:2],2'b0} == {pc_x_q[31:2],2'b0})//低32bit优先判断
            slot0_valid_r  = 1'b1;
        else if(fetch1_valid_i && {fetch1_pc_i[31:2],2'b0} == {pc_x_q[31:2],2'b0})
            slot1_valid_r  = 1'b1;
        else if(fetch0_valid_i || fetch1_valid_i)//两个指令都不匹配预测失败
            mispredicted_r = 1'b1;
    end
    //在exec阶段确认跳转真实情况，反馈到frontend
    assign branch_request_o = branch_csr_request_i || mispredicted_r;//CSR Branch or Branch misprediction
    assign branch_pc_o      = branch_csr_request_i ? branch_csr_pc_i : pc_x_q;
    assign branch_priv_o    = branch_csr_request_i ? branch_csr_priv_i : priv_x_q;
//-------------------------------------------------------------
// 分配(Allocation)电路,用来从发射队列中找到空闲的空间,将指令存储到其中
//-------------------------------------------------------------
    reg         opcode_a_valid_r;
    reg         opcode_b_valid_r;
    reg [1:0]   opcode_a_fault_r;
    reg [1:0]   opcode_b_fault_r;
    reg [31:0]  opcode_a_r;
    reg [31:0]  opcode_b_r;  
    reg [31:0]  opcode_a_pc_r;
    reg [31:0]  opcode_b_pc_r;  

    always @(*) begin
        opcode_a_valid_r = 1'b0;
        opcode_a_r       = 32'b0;
        opcode_a_pc_r    = 32'b0;
        opcode_a_fault_r = 2'b0;
        opcode_b_valid_r = 1'b0;
        opcode_b_r       = 32'b0;
        opcode_b_pc_r    = 32'b0;
        opcode_b_fault_r = 2'b0;
        if(slot0_valid_r) begin
            opcode_a_valid_r = 1'b1;
            opcode_a_r       = fetch0_instr_i;
            opcode_a_pc_r    = fetch0_pc_i;
            opcode_a_fault_r = {fetch0_fault_page_i,fetch0_fault_fetch_i};
            opcode_b_valid_r = fetch1_valid_i;
            opcode_b_r       = fetch1_instr_i;
            opcode_b_pc_r    = fetch1_pc_i;
            opcode_b_fault_r = {fetch1_fault_page_i,fetch1_fault_fetch_i};
        end
        else if(slot1_valid_r) begin//把字1的指令放到发射槽0（有些指令只能在发射槽0发射）
            opcode_a_valid_r = 1'b1;
            opcode_a_r       = fetch1_instr_i;
            opcode_a_pc_r    = fetch1_pc_i;
            opcode_a_fault_r = {fetch1_fault_page_i,fetch1_fault_fetch_i};
            opcode_b_valid_r = 1'b0;
            opcode_b_r       = 32'b0;
            opcode_b_pc_r    = 32'b0;
            opcode_b_fault_r = 2'b0;
        end
    end
    //两个发射槽装填指令
    wire [4:0]  issue_a_ra_idx_w   = opcode_a_r[19:15];
    wire [4:0]  issue_a_rb_idx_w   = opcode_a_r[24:20];
    wire [4:0]  issue_a_rd_idx_w   = opcode_a_r[11:7];
    wire        issue_a_sb_alloc_w = slot0_valid_r ? fetch0_instr_rd_valid_i : fetch1_instr_rd_valid_i;
    wire        issue_a_lsu_w      = slot0_valid_r ? fetch0_instr_lsu_i      : fetch1_instr_lsu_i; 
    wire        issue_a_csr_w      = slot0_valid_r ? fetch0_instr_csr_i      : fetch1_instr_csr_i;     
    wire        issue_a_div_w      = slot0_valid_r ? fetch0_instr_div_i      : fetch1_instr_div_i; 
    wire        issue_a_mul_w      = slot0_valid_r ? fetch0_instr_mul_i      : fetch1_instr_mul_i;     
    wire        issue_a_branch_w   = slot0_valid_r ? fetch0_instr_branch_i   : fetch1_instr_branch_i; 
    wire        issue_a_invalid_w  = slot0_valid_r ? fetch0_instr_invalid_i  : fetch1_instr_invalid_i;
    wire        issue_a_exec_w     = slot0_valid_r ? fetch0_instr_exec_i     : fetch1_instr_exec_i;  

    wire [4:0]  issue_b_ra_idx_w   = opcode_b_r[19:15];
    wire [4:0]  issue_b_rb_idx_w   = opcode_b_r[24:20];
    wire [4:0]  issue_b_rd_idx_w   = opcode_b_r[11:7];
    wire        issue_b_sb_alloc_w = fetch1_instr_rd_valid_i;
    wire        issue_b_lsu_w      = fetch1_instr_lsu_i;   
    wire        issue_b_csr_w      = fetch1_instr_csr_i;
    wire        issue_b_div_w      = fetch1_instr_div_i; 
    wire        issue_b_mul_w      = fetch1_instr_mul_i;  
    wire        issue_b_branch_w   = fetch1_instr_branch_i;    
    wire        issue_b_invalid_w  = fetch1_instr_invalid_i;
    wire        issue_b_exec_w     = fetch1_instr_exec_i;  

    //pipe_ctrl0 signal
    reg         opcode_a_issue_r; 
    reg         opcode_a_accept_r;
    wire        pipe0_load_e1_w;       
    wire        pipe0_store_e1_w;      
    wire        pipe0_mul_e1_w;        
    wire        pipe0_branch_e1_w;     
    wire [ 4:0] pipe0_rd_e1_w;         
    wire [31:0] pipe0_pc_e1_w;         
    wire [31:0] pipe0_opcode_e1_w;     
    wire [31:0] pipe0_operand_ra_e1_w; 
    wire [31:0] pipe0_operand_rb_e1_w; 
    wire        pipe0_load_e2_w;     
    wire        pipe0_mul_e2_w;      
    wire [ 4:0] pipe0_rd_e2_w;       
    wire [31:0] pipe0_result_e2_w;   
    wire        pipe0_stall_w;       
    wire        pipe0_squash_e1_e2_w;
    wire        pipe1_squash_e1_e2_w;
    wire        pipe0_valid_wb_w;
    wire        pipe0_csr_wb_w;
    wire [ 4:0] pipe0_rd_wb_w;
    wire [31:0] pipe0_result_wb_w;
    wire [31:0] pipe0_pc_wb_w;
    wire [31:0] pipe0_opc_wb_w;
    wire [31:0] pipe0_ra_val_wb_w;
    wire [31:0] pipe0_rb_val_wb_w;
    wire [`EXCEPTION_W-1:0] pipe0_exception_wb_w;
    wire [`EXCEPTION_W-1:0] issue_a_fault_w = opcode_a_fault_r[0] ? `EXCEPTION_FAULT_FETCH :
                                              opcode_a_fault_r[1] ? `EXCEPTION_PAGE_FAULT_INST : `EXCEPTION_W'h0;

pipe_ctrl //第4.5级流水线寄存器
#(
    .SUPPORT_LOAD_BYPASS(1),
    .SUPPORT_MUL_BYPASS (1)
)u0_pipe_ctrl
(
    .clk_i                      (clk_i                      ),
    .rstn_i                     (rstn_i                     ),

    .issue_valid_i              (opcode_a_issue_r           ),
    .issue_accept_i             (opcode_a_accept_r          ),
    .issue_stall_i              (stall_w                    ),
    //issue输入，打1/2/3拍输出
    .issue_rd_i                 (issue_a_rd_idx_w           ),//useless
    .issue_rd_valid_i           (issue_a_sb_alloc_w         ),
    .issue_lsu_i                (issue_a_lsu_w              ),
    .issue_csr_i                (issue_a_csr_w              ),
    .issue_div_i                (issue_a_div_w              ),
    .issue_mul_i                (issue_a_mul_w              ),
    .issue_branch_i             (issue_a_branch_w           ),  
    .issue_exception_i          (issue_a_fault_w            ),
    .issue_pc_i                 (opcode0_pc_o               ),//这四个输出是根据输入得到的译码结果
    .issue_opcode_i             (opcode0_opcode_o           ),
    .issue_operand_ra_i         (opcode0_ra_operand_o       ),
    .issue_operand_rb_i         (opcode0_rb_operand_o       ),
    .issue_branch_taken_i       (branch_d_exec0_request_i   ),
    .issue_branch_target_i      (branch_d_exec0_pc_i        ),
    .take_interrupt_i           (take_interrupt_i           ), 
    //----------------------------E1----------------------------Pre-decode和Issue间的第二级流水线寄存器
    //ALU，CSR result计算用一个周期
    .alu_result_e1_i            (writeback_exec0_value_i    ),
    .csr_result_value_e1_i      (csr_result_value_e1_i      ),
    .csr_result_write_e1_i      (csr_result_write_e1_i      ),
    .csr_result_wdata_e1_i      (csr_result_wdata_e1_i      ),
    .csr_result_exception_e1_i  (csr_result_exception_e1_i  ),
    //issue(decode)输入打一拍
    .load_e1_o                  (pipe0_load_e1_w            ),
    .store_e1_o                 (pipe0_store_e1_w           ),
    .mul_e1_o                   (pipe0_mul_e1_w             ),
    .branch_e1_o                (pipe0_branch_e1_w          ),
    .rd_e1_o                    (pipe0_rd_e1_w              ),
    .pc_e1_o                    (pipe0_pc_e1_w              ),
    .opcode_e1_o                (pipe0_opcode_e1_w          ),
    .operand_ra_e1_o            (pipe0_operand_ra_e1_w      ),
    .operand_rb_e1_o            (pipe0_operand_rb_e1_w      ),
    //----------------------------E2----------------------------E1和E2间的第三级流水线寄存器
    //一个两个周期，计算用一个周期，访存用一个周期
    .mem_complete_i             (writeback_mem_valid_i      ),
    .mem_result_e2_i            (writeback_mem_value_i      ), 
    .mem_exception_e2_i         (writeback_mem_exception_i  ),
    .mul_result_e2_i            (writeback_mul_value_i      ),
    //issue(decode)输入打两拍
    .load_e2_o                  (pipe0_load_e2_w            ),
    .mul_e2_o                   (pipe0_mul_e2_w             ),
    .rd_e2_o                    (pipe0_rd_e2_w              ),//其中3个信号打两拍
    .result_e2_o                (pipe0_result_e2_w          ),
    .stall_o                    (pipe0_stall_raw_w          ),
    .squash_e1_e2_o             (pipe0_squash_e1_e2_w       ),
    .squash_e1_e2_i             (pipe1_squash_e1_e2_w       ),
    .squash_wb_i                (1'b0                       ),
    //除法结果不参与顺序执行，只要写好了就输入，除法会暂停流水线
    .div_complete_i             (writeback_div_valid_i      ), 
    .div_result_i               (writeback_div_value_i      ),
    //----------------------------WB----------------------------E2和WB之间的第四级流水线寄存器
    .valid_wb_o                 (pipe0_valid_wb_w           ),
    .csr_wb_o                   (pipe0_csr_wb_w             ),
    .rd_wb_o                    (pipe0_rd_wb_w              ),
    .result_wb_o                (pipe0_result_wb_w          ),
    .pc_wb_o                    (pipe0_pc_wb_w              ),
    .opcode_wb_o                (pipe0_opc_wb_w             ),
    .operand_ra_wb_o            (pipe0_ra_val_wb_w          ),
    .operand_rb_wb_o            (pipe0_rb_val_wb_w          ),
    .exception_wb_o             (pipe0_exception_wb_w       ),

    .csr_write_wb_o             (csr_writeback_write_o      ),
    .csr_waddr_wb_o             (csr_writeback_waddr_o      ),
    .csr_wdata_wb_o             (csr_writeback_wdata_o      )

);
    assign exec0_hold_o = stall_w;
    assign mul_hold_o   = stall_w;
    //pipe_ctrl1 signal
    reg         opcode_b_issue_r; 
    reg         opcode_b_accept_r;

    wire        pipe1_load_e1_w;       
    wire        pipe1_store_e1_w;      
    wire        pipe1_mul_e1_w;        
    wire        pipe1_branch_e1_w;     
    wire [4:0]  pipe1_rd_e1_w;         
    wire [31:0] pipe1_pc_e1_w;         
    wire [31:0] pipe1_opcode_e1_w;     
    wire [31:0] pipe1_operand_ra_e1_w; 
    wire [31:0] pipe1_operand_rb_e1_w; 
    wire        pipe1_load_e2_w;     
    wire        pipe1_mul_e2_w;      
    wire [4:0]  pipe1_rd_e2_w;       
    wire [31:0] pipe1_result_e2_w;   
    wire        pipe1_stall_w;       

    wire        pipe1_valid_wb_w;
    wire [4:0]  pipe1_rd_wb_w;
    wire [31:0] pipe1_result_wb_w;
    wire [31:0] pipe1_pc_wb_w;// Division operations take 2 - 34 cycles and stall
// the pipeline (complete out-of-pipe) until completed.
    wire [31:0] pipe1_opc_wb_w;
    wire [31:0] pipe1_ra_val_wb_w;
    wire [31:0] pipe1_rb_val_wb_w;
    wire [`EXCEPTION_W-1:0] pipe1_exception_wb_w;
    wire    [`EXCEPTION_W-1:0] issue_b_fault_w = opcode_b_fault_r[0] ? `EXCEPTION_FAULT_FETCH :
                                                 opcode_b_fault_r[1] ? `EXCEPTION_PAGE_FAULT_INST : `EXCEPTION_W'h0;
    
pipe_ctrl 
#(
    .SUPPORT_LOAD_BYPASS(1),
    .SUPPORT_MUL_BYPASS (1)
)u1_pipe_ctrl
(
    .clk_i                      (clk_i                      ),
    .rstn_i                     (rstn_i                      ),

    .issue_valid_i              (opcode_b_issue_r           ),
    .issue_accept_i             (opcode_b_accept_r          ),
    .issue_stall_i              (stall_w                    ),
    //issue输入，打1/2/3拍输出
    .issue_rd_i                 (issue_b_rd_idx_w           ), 
    .issue_rd_valid_i           (issue_b_sb_alloc_w         ),
    .issue_lsu_i                (issue_b_lsu_w              ),
    .issue_csr_i                (1'b0                       ),
    .issue_div_i                (1'b0                       ),
    .issue_mul_i                (issue_b_mul_w              ),
    .issue_branch_i             (issue_b_branch_w           ),  
    .issue_exception_i          (issue_b_fault_w            ),
    .issue_pc_i                 (opcode1_pc_o               ),
    .issue_opcode_i             (opcode1_opcode_o           ),
    .issue_operand_ra_i         (opcode1_ra_operand_o       ),
    .issue_operand_rb_i         (opcode1_rb_operand_o       ),
    .issue_branch_taken_i       (branch_d_exec1_request_i   ),
    .issue_branch_target_i      (branch_d_exec1_pc_i        ),
    .take_interrupt_i           (take_interrupt_i           ), 
    //Stage 1 :ALU result
    .alu_result_e1_i            (writeback_exec1_value_i    ),
    .csr_result_value_e1_i      (csr_result_value_e1_i      ),
    .csr_result_write_e1_i      (csr_result_write_e1_i      ),
    .csr_result_wdata_e1_i      (csr_result_wdata_e1_i      ),
    .csr_result_exception_e1_i  (csr_result_exception_e1_i  ),
    //输入打一拍后在Execution stage1阶段输出
    .load_e1_o                  (pipe1_load_e1_w            ),
    .store_e1_o                 (pipe1_store_e1_w           ),
    .mul_e1_o                   (pipe1_mul_e1_w             ),
    .branch_e1_o                (pipe1_branch_e1_w          ),
    .rd_e1_o                    (pipe1_rd_e1_w              ),
    .pc_e1_o                    (pipe1_pc_e1_w              ),
    .opcode_e1_o                (pipe1_opcode_e1_w          ),
    .operand_ra_e1_o            (pipe1_operand_ra_e1_w      ),
    .operand_rb_e1_o            (pipe1_operand_rb_e1_w      ),
    //Stage 2 :bypass （前馈）
    .mem_complete_i             (writeback_mem_valid_i      ),
    .mem_result_e2_i            (writeback_mem_value_i      ), 
    .mem_exception_e2_i         (writeback_mem_exception_i  ),
    .mul_result_e2_i            (writeback_mul_value_i      ),
    //Execution stage2
    .load_e2_o                  (pipe1_load_e2_w            ),
    .mul_e2_o                   (pipe1_mul_e2_w             ),
    .rd_e2_o                    (pipe1_rd_e2_w              ),
    .result_e2_o                (pipe1_result_e2_w          ),
    .stall_o                    (pipe1_stall_raw_w          ),
    .squash_e1_e2_o             (pipe1_squash_e1_e2_w       ),
    .squash_e1_e2_i             (pipe0_squash_e1_e2_w       ),
    .squash_wb_i                (pipe0_squash_e1_e2_w       ),
    //output of pipe: Divide_Result
    .div_complete_i             (writeback_div_valid_i      ), 
    .div_result_i               (writeback_div_value_i      ),
    //commit打三拍输出
    .valid_wb_o                 (pipe1_valid_wb_w           ),
    .csr_wb_o                   (                           ),
    .rd_wb_o                    (pipe1_rd_wb_w              ),
    .result_wb_o                (pipe1_result_wb_w          ),
    .pc_wb_o                    (pipe1_pc_wb_w              ),
    .opcode_wb_o                (pipe1_opc_wb_w             ),
    .operand_ra_wb_o            (pipe1_ra_val_wb_w          ),
    .operand_rb_wb_o            (pipe1_rb_val_wb_w          ),
    .exception_wb_o             (pipe1_exception_wb_w       ),

    .csr_write_wb_o             (),
    .csr_waddr_wb_o             (),
    .csr_wdata_wb_o             ()

);

    assign exec1_hold_o = stall_w;

    assign csr_writeback_exception_o      = pipe0_exception_wb_w | pipe1_exception_wb_w;
    assign csr_writeback_exception_pc_o   = (|pipe0_exception_wb_w) ? pipe0_pc_wb_w     : pipe1_pc_wb_w;
    assign csr_writeback_exception_addr_o = (|pipe0_exception_wb_w) ? pipe0_result_wb_w : pipe1_result_wb_w;

//-------------------------------------------------------------
// Branch predictor info(花了一个周期)
//-------------------------------------------------------------
    //将执行阶段的正确信息用于分支预测学习，并更新分支预测
    assign branch_info_request_o      = mispredicted_r;
    assign branch_info_is_taken_o     = (pipe1_branch_e1_w && branch_exec1_is_taken_i)     | (pipe0_branch_e1_w && branch_exec0_is_taken_i);
    assign branch_info_is_not_taken_o = (pipe1_branch_e1_w && branch_exec1_is_not_taken_i) | (pipe0_branch_e1_w && branch_exec0_is_not_taken_i);
    assign branch_info_is_call_o      = (pipe1_branch_e1_w && branch_exec1_is_call_i)      | (pipe0_branch_e1_w && branch_exec1_is_call_i);
    assign branch_info_is_ret_o       = (pipe1_branch_e1_w && branch_exec1_is_ret_i)       | (pipe0_branch_e1_w && branch_exec1_is_ret_i);
    assign branch_info_is_jmp_o       = (pipe1_branch_e1_w && branch_exec1_is_jmp_i)       | (pipe0_branch_e1_w && branch_exec1_is_jmp_i);
    assign branch_info_source_o       = (pipe1_branch_e1_w && branch_exec1_request_i)    ? branch_exec1_source_i : branch_exec0_source_i;//先用旧的结果
    assign branch_info_pc_o           = (pipe1_branch_e1_w && branch_exec1_request_i)    ? branch_exec1_pc_i : branch_exec0_pc_i;//先用旧的结果

    assign stall_w   = pipe0_stall_raw_w | pipe1_stall_raw_w;

//-------------------------------------------------------------
// 阻塞事件（div,CSR)     
//-------------------------------------------------------------
    reg div_pending_q;
    reg csr_pending_q;
    //除法需要2～34Cycle,此期间流水线暂停
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            div_pending_q <= 1'b0;
        else if(pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
            div_pending_q <= 1'b0;
        else if(div_opcode_valid_o && issue_a_div_w)
            div_pending_q <= 1'b1;
        else if(writeback_div_valid_i)
            div_pending_q <= 1'b0;
    end
    //CSR可能冲刷流水线
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            csr_pending_q <= 1'b0;
        else if(pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w) 
            csr_pending_q <= 1'b0;
        else if(csr_opcode_valid_o && issue_a_csr_w)
            csr_pending_q <= 1'b1;
        else if(pipe0_csr_wb_w)
            csr_pending_q <= 1'b0;
    end
    //异常冲刷流水线
    assign  squash_w = pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w;

//-------------------------------------------------------------
// 发射逻辑 Hazard detect
//-------------------------------------------------------------
    reg [31:0]  scoreboard_r;
    reg         pipe1_mux_lsu_r;
    reg         pipe1_mux_mul_r;

    //检测指令是否可以用第二个发射槽
    wire pipe1_ok_w = issue_b_exec_w || issue_b_lsu_w || issue_b_mul_w || issue_b_branch_w ;
//????????AB槽指令类型存在约束？
    wire dual_issue_ok_w = enable_dual_issue_w && //系统使能
                           pipe1_ok_w &&
                          (((issue_a_exec_w || issue_a_lsu_w || issue_a_mul_w) && issue_b_exec_w)   ||
                           ((issue_a_exec_w || issue_a_lsu_w || issue_a_mul_w) && issue_b_branch_w) ||
                           ((issue_a_exec_w || issue_a_mul_w) && issue_b_lsu_w)                     ||
                           ((issue_a_exec_w || issue_a_lsu_w) && issue_a_mul_w))                    &&
                           ~take_interrupt_i;
    always @(*) begin
        opcode_a_issue_r     = 1'b0;
        opcode_b_issue_r     = 1'b0;
        opcode_a_accept_r    = 1'b0;
        opcode_b_accept_r    = 1'b0;
        scoreboard_r         = 32'b0;//0为空闲
        pipe1_mux_lsu_r      = 1'b0;
        pipe1_mux_mul_r      = 1'b0;
        //SUPPORT_LOAD_PASS    load/mul  >= 1cycle
        if (pipe0_load_e1_w || pipe0_mul_e1_w)
            scoreboard_r[pipe0_rd_e1_w] = 1'b1;
        if (pipe1_load_e1_w || pipe1_mul_e1_w)
            scoreboard_r[pipe1_rd_e1_w] = 1'b1;
        //不要在load的循环中开始div、mul或CSR运算（只留下ALU运算和branch）
        if ((pipe0_load_e1_w || pipe0_store_e1_w || pipe1_load_e1_w || pipe1_store_e1_w ) && (issue_a_mul_w || issue_a_div_w || issue_a_csr_w))
            scoreboard_r = 32'hFFFFFFFF;
        //暂停
//-------------------------------------------------------------
// 唤醒电路：判断数据是准备好，唤醒指令
//-------------------------------------------------------------
        //发射槽a(可发射种类：lsu, branch, alu, mul, div, csr)
        if(lsu_stall_i || stall_w || div_pending_q || csr_pending_q) 
            ;
        else if(opcode_a_valid_r && !(fetch0_instr_rs1_valid_i && scoreboard_r[issue_a_ra_idx_w]) 
                 && !(fetch0_instr_rs2_valid_i && scoreboard_r[issue_a_rb_idx_w]) && !(fetch0_instr_rd_valid_i && scoreboard_r[issue_a_rd_idx_w])) begin
            opcode_a_issue_r  = 1'b1;
            opcode_a_accept_r = 1'b1;
            if (opcode_a_accept_r && issue_a_sb_alloc_w && (|issue_a_rd_idx_w))
                scoreboard_r[issue_a_rd_idx_w] = 1'b1;//用到该RD,置为繁忙
        end
        
        //发射槽b(可发射种类：lsu, branch, alu, mul)
        if(lsu_stall_i || stall_w || div_pending_q || csr_pending_q) 
            ;
        else if (dual_issue_ok_w && opcode_b_valid_r && opcode_a_accept_r && !(fetch1_instr_rs1_valid_i && scoreboard_r[issue_b_ra_idx_w]) 
                    && !(fetch1_instr_rs2_valid_i && scoreboard_r[issue_b_rb_idx_w]) && !(fetch1_instr_rd_valid_i && scoreboard_r[issue_b_rd_idx_w])) begin
            opcode_b_issue_r  = 1'b1;
            opcode_b_accept_r = 1'b1;
            pipe1_mux_lsu_r   = issue_b_lsu_w;
            pipe1_mux_mul_r   = issue_b_mul_w;
            if (opcode_b_accept_r && issue_b_sb_alloc_w && (|issue_b_rd_idx_w))
                scoreboard_r[issue_b_rd_idx_w] = 1'b1;
        end    
    end
    assign lsu_opcode_valid_o   = (pipe1_mux_lsu_r ? opcode_b_issue_r : opcode_a_issue_r) && ~take_interrupt_i;
    assign mul_opcode_valid_o   = enable_muldiv_w && (pipe1_mux_mul_r ? opcode_b_issue_r :opcode_a_issue_r); 
    assign div_opcode_valid_o   = enable_muldiv_w && opcode_a_issue_r;
    assign interrupt_inhibit_o  = csr_pending_q || issue_a_csr_w;

    assign exec0_opcode_valid_o = opcode_a_issue_r;
    assign exec1_opcode_valid_o = opcode_b_issue_r;

    assign dual_issue_w         = opcode_b_issue_r && opcode_b_accept_r && ~take_interrupt_i;
    assign single_issue_w       = opcode_a_issue_r && opcode_a_accept_r && ~dual_issue_w && ~take_interrupt_i;

    assign fetch0_accept_o      = ((slot0_valid_r && opcode_a_accept_r) || slot1_valid_r) && ~take_interrupt_i;
    assign fetch1_accept_o      = ((slot1_valid_r && opcode_a_accept_r) || opcode_b_accept_r) && ~take_interrupt_i;



//-------------------------------------------------------------
// Register File
//-------------------------------------------------------------     
    wire [31:0] issue_a_ra_value_w;
    wire [31:0] issue_a_rb_value_w;
    wire [31:0] issue_b_ra_value_w;
    wire [31:0] issue_b_rb_value_w;
    //写回是最后的第五级流水线寄存器
    regfile u_regfile//写延迟一拍，读无延迟
    (
        .clk_i       (clk_i             ),
        .rstn_i      (rstn_i            ),
        //from pipe ctrl
        .rd0_i       (pipe0_rd_wb_w     ),
        .rd0_value_i (pipe0_result_wb_w ),
        .rd1_i       (pipe1_rd_wb_w     ),    
        .rd1_value_i (pipe1_result_wb_w ),
        //from issue decode
        .ra0_i       (issue_a_ra_idx_w  ),
        .rb0_i       (issue_a_rb_idx_w  ),
        .ra0_value_o (issue_a_ra_value_w),
        .rb0_value_o (issue_a_rb_value_w),

        .ra1_i       (issue_b_ra_idx_w  ),
        .rb1_i       (issue_b_rb_idx_w  ), 
        .ra1_value_o (issue_b_ra_value_w),
        .rb1_value_o (issue_b_rb_value_w)
    );


//-------------------------------------------------------------
//发射槽0
//-------------------------------------------------------------
    assign opcode0_opcode_o = opcode_a_r;
    assign opcode0_pc_o     = opcode_a_pc_r;
    assign opcode0_rd_idx_o = issue_a_rd_idx_w;
    assign opcode0_ra_idx_o = issue_a_ra_idx_w;
    assign opcode0_rb_idx_o = issue_a_rb_idx_w;
    assign opcode0_invalid_o= 1'b0;  

    reg [31:0] issue_a_ra_value_r;
    reg [31:0] issue_a_rb_value_r;

    //bypass前馈解决写后读
    always @(*) begin
        issue_a_ra_value_r = issue_a_ra_value_w;
        issue_a_rb_value_r = issue_a_rb_value_w;
        //为什么4个if? 因为双发射，需要操作4个寄存器，需要确定他们是否在被更改
        //WB Bypass
        if (pipe0_rd_wb_w == issue_a_ra_idx_w)
            issue_a_ra_value_r = pipe0_result_wb_w;
        if (pipe0_rd_wb_w == issue_a_rb_idx_w)
            issue_a_rb_value_r = pipe0_result_wb_w;
        if (pipe1_rd_wb_w == issue_a_ra_idx_w)
            issue_a_ra_value_r = pipe1_result_wb_w;
        if (pipe1_rd_wb_w == issue_a_rb_idx_w)
            issue_a_rb_value_r = pipe1_result_wb_w;
        //E2
        if (pipe0_rd_e2_w == issue_a_ra_idx_w)
            issue_a_ra_value_r = pipe0_result_e2_w;
        if (pipe0_rd_e2_w == issue_a_rb_idx_w)
            issue_a_rb_value_r = pipe0_result_e2_w;
        if (pipe1_rd_e2_w == issue_a_ra_idx_w)
            issue_a_ra_value_r = pipe1_result_e2_w;
        if (pipe1_rd_e2_w == issue_a_rb_idx_w)
            issue_a_rb_value_r = pipe1_result_e2_w;
        //E1
        if (pipe0_rd_e1_w == issue_a_ra_idx_w)
            issue_a_ra_value_r = writeback_exec0_value_i;
        if (pipe0_rd_e1_w == issue_a_rb_idx_w)
            issue_a_rb_value_r = writeback_exec0_value_i;
        if (pipe1_rd_e1_w == issue_a_ra_idx_w)
            issue_a_ra_value_r = writeback_exec1_value_i;
        if (pipe1_rd_e1_w == issue_a_rb_idx_w)
            issue_a_rb_value_r = writeback_exec1_value_i;
        //reg x0
        if (issue_a_ra_idx_w == 5'b0)
            issue_a_ra_value_r = 32'b0;
        if (issue_a_rb_idx_w == 5'b0)
            issue_a_rb_value_r = 32'b0;
    end

    assign opcode0_ra_operand_o = issue_a_ra_value_r;
    assign opcode0_rb_operand_o = issue_a_rb_value_r;

//-------------------------------------------------------------
//发射槽1
//-------------------------------------------------------------
    assign opcode1_opcode_o = opcode_b_r;
    assign opcode1_pc_o     = opcode_b_pc_r;
    assign opcode1_rd_idx_o = issue_b_rd_idx_w;
    assign opcode1_ra_idx_o = issue_b_ra_idx_w;
    assign opcode1_rb_idx_o = issue_b_rb_idx_w;
    assign opcode1_invalid_o= 1'b0;
    
    reg [31:0] issue_b_ra_value_r;
    reg [31:0] issue_b_rb_value_r;

    //bypass前馈解决写后读
    always @(*) begin
        issue_b_ra_value_r = issue_b_ra_value_w;
        issue_b_rb_value_r = issue_b_rb_value_w;
        //为什么4个if? 因为双发射，需要操作4个寄存器，需要确定他们是否在被更改
        //WB Bypass
        if (pipe0_rd_wb_w == issue_b_ra_idx_w)
            issue_b_ra_value_r = pipe0_result_wb_w;
        if (pipe0_rd_wb_w == issue_b_rb_idx_w)
            issue_b_rb_value_r = pipe0_result_wb_w;
        if (pipe1_rd_wb_w == issue_b_ra_idx_w)
            issue_b_ra_value_r = pipe1_result_wb_w;
        if (pipe1_rd_wb_w == issue_b_rb_idx_w)
            issue_b_rb_value_r = pipe1_result_wb_w;
        // Bypass - E2
        if (pipe0_rd_e2_w == issue_b_ra_idx_w)
            issue_b_ra_value_r = pipe0_result_e2_w;
        if (pipe0_rd_e2_w == issue_b_rb_idx_w)
            issue_b_rb_value_r = pipe0_result_e2_w;
        if (pipe1_rd_e2_w == issue_b_ra_idx_w)
            issue_b_ra_value_r = pipe1_result_e2_w;
        if (pipe1_rd_e2_w == issue_b_rb_idx_w)
            issue_b_rb_value_r = pipe1_result_e2_w;
        // Bypass - E1
        if (pipe0_rd_e1_w == issue_b_ra_idx_w)
            issue_b_ra_value_r = writeback_exec0_value_i;
        if (pipe0_rd_e1_w == issue_b_rb_idx_w)
            issue_b_rb_value_r = writeback_exec0_value_i;
        if (pipe1_rd_e1_w == issue_b_ra_idx_w)
            issue_b_ra_value_r = writeback_exec1_value_i;
        if (pipe1_rd_e1_w == issue_b_rb_idx_w)
            issue_b_rb_value_r = writeback_exec1_value_i;
        // Reg 0 source
        if (issue_b_ra_idx_w == 5'b0)
            issue_b_ra_value_r = 32'b0;
        if (issue_b_rb_idx_w == 5'b0)
            issue_b_rb_value_r = 32'b0;
    end

    assign opcode1_ra_operand_o = issue_b_ra_value_r;
    assign opcode1_rb_operand_o = issue_b_rb_value_r;

    //to LSU
    assign lsu_opcode_opcode_o      = pipe1_mux_lsu_r ? opcode1_opcode_o     : opcode0_opcode_o;            
    assign lsu_opcode_ra_operand_o  = pipe1_mux_lsu_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
    assign lsu_opcode_rb_operand_o  = pipe1_mux_lsu_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
    //to MUL
    assign mul_opcode_opcode_o      = pipe1_mux_mul_r ? opcode1_opcode_o     : opcode0_opcode_o;              
    assign mul_opcode_ra_operand_o  = pipe1_mux_mul_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
    assign mul_opcode_rb_operand_o  = pipe1_mux_mul_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
    //to CSR
    assign csr_opcode_valid_o      = opcode_a_issue_r && ~take_interrupt_i; 
    assign csr_opcode_opcode_o      = opcode0_opcode_o;       
    assign csr_opcode_pc_o          = opcode0_pc_o;               
    assign csr_opcode_rd_idx_o      = opcode0_rd_idx_o;       
    assign csr_opcode_ra_idx_o      = opcode0_ra_idx_o;       
    assign csr_opcode_rb_idx_o      = opcode0_rb_idx_o;       
    assign csr_opcode_ra_operand_o  = opcode0_ra_operand_o;
    assign csr_opcode_rb_operand_o  = opcode0_rb_operand_o;
    assign csr_opcode_invalid_o     = opcode_a_issue_r && issue_a_invalid_w;






endmodule