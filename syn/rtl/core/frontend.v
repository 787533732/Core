//取指模块
//分支预测和取指在同一个周期，从Icache取指花一个周期，即第一级流水寄存器
module frontend 
#(
    parameter  SUPPORT_BRANCH_PREDICTION = 1  ,
    parameter  GSHARE_ENABLE             = 1  ,  
    parameter  PHT_ENABLE                = 1  ,  
    parameter  RAS_ENABLE                = 1  ,  
    parameter  NUM_PHT_ENTRIES           = 512,
    parameter  NUM_PHT_ENTRIES_W         = 9  ,  
    parameter  NUM_RAS_ENTRIES           = 8  ,  
    parameter  NUM_RAS_ENTRIES_W         = 3  ,  
    parameter  NUM_BTB_ENTRIES           = 32 , 
    parameter  NUM_BTB_ENTRIES_W         = 5  ,  
    parameter  SUPPORT_MMU               = 1  ,
    parameter  SUPPORT_MULDIV            = 1  ,       
    parameter  EXTRA_DECODE_STAGE        = 0  
)
(
    input   wire                clk_i                     ,
    input   wire                rstn_i                    ,
    input   wire                fetch_invalidate_i        ,//from CSR
//*********************************from issue*******************************//
    input   wire                fetch0_accept_i           ,
    input   wire                fetch1_accept_i           ,
    //(clear error data)
    input   wire                branch_request_i          ,//issue发现分支预测跳转错误或者出现异常
    input   wire [31:0]         branch_pc_i               ,
    input   wire [ 1:0]         branch_priv_i             ,
    //在执行阶段得到实际的跳转信息，发送到issue确认后，输入用于分支预测学习
    input   wire                branch_info_request_i     , 
    input   wire                branch_info_is_taken_i    ,
    input   wire                branch_info_is_not_taken_i, 
    input   wire [31:0]         branch_info_source_i      ,
    input   wire                branch_info_is_call_i     ,
    input   wire                branch_info_is_ret_i      ,
    input   wire                branch_info_is_jmp_i      ,
    input   wire [31:0]         branch_info_pc_i          ,
    //fetch从i-cache读取数据
    input   wire                icache_accept_i           ,
    input   wire [63:0]         icache_inst_i             ,//延迟一拍取到指令//第二级流水线寄存器
    input   wire                icache_valid_i            ,
    input   wire                icache_error_i            ,
    input   wire                icache_page_fault_i       ,
    output  wire                icache_rd_o               ,
    output  wire [31:0]         icache_pc_o               ,//取指PC  
    output  wire [ 1:0]         icache_priv_o             ,
    output  wire                icache_flush_o            ,
    output  wire                icache_invalidate_o       ,
    //from decode to issue
    output  wire [31:0]         fetch0_instr_o            ,   
    output  wire                fecth0_valid_o            ,
    output  wire [31:0]         fetch0_pc_o               ,
    output  wire                fetch0_fault_fetch_o      ,
    output  wire                fetch0_fault_page_o       ,
    output  wire                fetch0_instr_invalid_o    ,
    output  wire                fetch0_instr_exec_o       ,
    output  wire                fetch0_instr_lsu_o        ,
    output  wire                fetch0_instr_branch_o     ,
    output  wire                fetch0_instr_mul_o        ,
    output  wire                fetch0_instr_div_o        ,
    output  wire                fetch0_instr_csr_o        ,
    output  wire                fetch0_instr_rs1_valid_o  ,
    output  wire                fetch0_instr_rs2_valid_o  ,
    output  wire                fetch0_instr_rd_valid_o   ,
    output  wire [31:0]         fetch1_instr_o            ,
    output  wire                fecth1_valid_o            ,
    output  wire [31:0]         fetch1_pc_o               ,
    output  wire                fetch1_fault_fetch_o      ,
    output  wire                fetch1_fault_page_o       ,
    output  wire                fetch1_instr_invalid_o    ,
    output  wire                fetch1_instr_exec_o       ,
    output  wire                fetch1_instr_lsu_o        ,
    output  wire                fetch1_instr_branch_o     ,
    output  wire                fetch1_instr_mul_o        ,
    output  wire                fetch1_instr_div_o        ,
    output  wire                fetch1_instr_csr_o        ,
    output  wire                fetch1_instr_rs1_valid_o  ,
    output  wire                fetch1_instr_rs2_valid_o  ,
    output  wire                fetch1_instr_rd_valid_o     
);   
    wire        fetch_accept_w;
    wire [63:0] fetch_instr_w;
    wire        fetch_valid_w;
    wire        fetch_fault_fetch_w;
    wire        fetch_fault_page_w;
    wire [ 1:0] fetch_pred_branch_w;
    wire [31:0] fetch_pc_w;
    wire [31:0] fetch_pc_f_w;
    wire        pc_accept_w;
    wire [31:0] next_pc_f_w;
    wire [ 1:0] next_taken_f_w;

bpu
#(
    .SUPPORT_BRANCH_PREDICTION(SUPPORT_BRANCH_PREDICTION ),
    .GSHARE_ENABLE            (GSHARE_ENABLE             ),
    .PHT_ENABLE               (PHT_ENABLE                ),
    .RAS_ENABLE               (RAS_ENABLE                ),
    .NUM_PHT_ENTRIES          (NUM_PHT_ENTRIES           ),
    .NUM_PHT_ENTRIES_W        (NUM_PHT_ENTRIES_W         ),
    .NUM_RAS_ENTRIES          (NUM_RAS_ENTRIES           ),
    .NUM_RAS_ENTRIES_W        (NUM_RAS_ENTRIES_W         ),
    .NUM_BTB_ENTRIES          (NUM_BTB_ENTRIES           ),
    .NUM_BTB_ENTRIES_W        (NUM_BTB_ENTRIES_W         )
)
u_bpu
(
    .clk_i                    (clk_i                     ),
    .rstn_i                   (rstn_i                    ),
    //用于分支预测学习
    .branch_request_i         (branch_info_request_i     ),
    .branch_is_taken_i        (branch_info_is_taken_i    ),
    .branch_is_not_taken_i    (branch_info_is_not_taken_i),
    .branch_is_call_i         (branch_info_is_call_i     ),
    .branch_is_ret_i          (branch_info_is_ret_i      ),
    .branch_is_jmp_i          (branch_info_is_jmp_i      ),
    .branch_source_i          (branch_info_source_i      ),
    .branch_pc_i              (branch_info_pc_i          ),
    //进行分支预测需要的信息
    .pc_f_i                   (fetch_pc_f_w              ),
    .pc_accept_i              (pc_accept_w               ),
    //组合逻辑得到下个PC
    .next_pc_f_o              (next_pc_f_w               ),
    .next_taken_f_o           (next_taken_f_w            ) 
);

decode//预译码
#(
    .SUPPORT_MULDIV              (SUPPORT_MULDIV    ),
    .EXTRA_DECODE_STAGE          (EXTRA_DECODE_STAGE)
) 
u_decode
(
    .clk_i                       (clk_i),
    .rstn_i                      (rstn_i),
    .branch_request_i            (branch_request_i       ),//clear
    //from fetch
    .fetch_in_accept_o           (fetch_accept_w         ),
    .fetch_in_instr_i            (fetch_instr_w          ),
    .fetch_in_valid_i            (fetch_valid_w          ),
    .fetch_in_fault_fetch_i      (fetch_fault_fetch_w    ),
    .fetch_in_fault_page_i       (fetch_fault_page_w     ),
    .fetch_in_pred_branch_i      (fetch_pred_branch_w    ),
    .fetch_in_pc_i               (fetch_pc_w             ),
    //output
    .fetch_out0_accept_i         (fetch0_accept_i        ),
    .fetch_out1_accept_i         (fetch1_accept_i        ),
    //output
    .fetch_out0_instr_o          (fetch0_instr_o         ),
    .fetch_out0_valid_o          (fecth0_valid_o         ),
    .fetch_out0_fault_fetch_o    (fetch0_fault_fetch_o   ),
    .fetch_out0_fault_page_o     (fetch0_fault_page_o    ),
    .fetch_out0_pc_o             (fetch0_pc_o            ),
    .fetch_out0_instr_invalid_o  (fetch0_instr_invalid_o ),
    .fetch_out0_instr_exec_o     (fetch0_instr_exec_o    ),           
    .fetch_out0_instr_lsu_o      (fetch0_instr_lsu_o     ),
    .fetch_out0_instr_branch_o   (fetch0_instr_branch_o  ),
    .fetch_out0_instr_mul_o      (fetch0_instr_mul_o     ),      
    .fetch_out0_instr_div_o      (fetch0_instr_div_o     ),
    .fetch_out0_instr_csr_o      (fetch0_instr_csr_o     ),
    .fetch_out0_instr_rs1_valid_o(fetch0_instr_rs1_valid_o),
    .fetch_out0_instr_rs2_valid_o(fetch0_instr_rs2_valid_o),
    .fetch_out0_instr_rd_valid_o (fetch0_instr_rd_valid_o),
    .fetch_out1_instr_o          (fetch1_instr_o         ),
    .fetch_out1_valid_o          (fecth1_valid_o         ),
    .fetch_out1_fault_fetch_o    (fetch1_fault_fetch_o   ),
    .fetch_out1_fault_page_o     (fetch1_fault_page_o    ),
    .fetch_out1_pc_o             (fetch1_pc_o            ),
    .fetch_out1_instr_invalid_o  (fetch1_instr_invalid_o ),
    .fetch_out1_instr_exec_o     (fetch1_instr_exec_o    ),           
    .fetch_out1_instr_lsu_o      (fetch1_instr_lsu_o     ),
    .fetch_out1_instr_branch_o   (fetch1_instr_branch_o  ),
    .fetch_out1_instr_mul_o      (fetch1_instr_mul_o     ),      
    .fetch_out1_instr_div_o      (fetch1_instr_div_o     ),
    .fetch_out1_instr_csr_o      (fetch1_instr_csr_o     ),
    .fetch_out1_instr_rs1_valid_o(fetch1_instr_rs1_valid_o),
    .fetch_out1_instr_rs2_valid_o(fetch1_instr_rs2_valid_o),
    .fetch_out1_instr_rd_valid_o (fetch1_instr_rd_valid_o)
);

fetch 
#(
    .SUPPORT_MMU(SUPPORT_MMU)
)
u_fetch
(
    .clk_i               (clk_i                 ),
    .rstn_i              (rstn_i                ),
    .fetch_invalidate_i  (fetch_invalidate_i    ),//clear
    //input
    .branch_request_i    (branch_request_i      ),
    .branch_pc_i         (branch_pc_i           ),
    .branch_priv_i       (branch_priv_i         ),
    //from bpu
    .next_pc_f_i         (next_pc_f_w           ),
    .next_taken_f_i      (next_taken_f_w        ),
    //i-cache
    .icache_accept_i     (icache_accept_i       ),
    .icache_inst_i       (icache_inst_i         ),
    .icache_valid_i      (icache_valid_i        ),
    .icache_error_i      (icache_error_i        ),
    .icache_page_fault_i (icache_page_fault_i   ),
    .icache_rd_o         (icache_rd_o           ),
    .icache_pc_o         (icache_pc_o           ),
    .icache_priv_o       (icache_priv_o         ),
    .icache_flush_o      (icache_flush_o        ),
    .icache_invalidate_o (icache_invalidate_o   ),
    //to decode
    .fetch_accept_i      (fetch_accept_w        ),
    .fetch_instr_o       (fetch_instr_w         ),
    .fetch_valid_o       (fetch_valid_w         ),
    .fetch_fault_page_o  (fetch_fault_page_w    ),
    .fetch_fault_fetch_o (fetch_fault_fetch_w   ),
    .fetch_pred_branch_o (fetch_pred_branch_w   ),
    .fetch_pc_o          (fetch_pc_w            ),  
    //to bpu
    .pc_f_o              (fetch_pc_f_w          ),
    .pc_accept_o         (pc_accept_w           )
);


endmodule