module core 
#(
    parameter SUPPORT_BRANCH_PREDICTION = 1            ,
    parameter GSHARE_ENABLE             = 1            ,  
    parameter PHT_ENABLE                = 1            ,  
    parameter RAS_ENABLE                = 1            ,  
    parameter NUM_PHT_ENTRIES           = 512          ,
    parameter NUM_PHT_ENTRIES_W         = 9            ,  
    parameter NUM_RAS_ENTRIES           = 8            ,  
    parameter NUM_RAS_ENTRIES_W         = 3            ,  
    parameter NUM_BTB_ENTRIES           = 32           , 
    parameter NUM_BTB_ENTRIES_W         = 5            ,  
    parameter SUPPORT_MMU               = 0            ,
    parameter SUPPORT_MULDIV            = 1            ,
    parameter SUPPORT_SUPER             = 0            ,
    parameter EXTRA_DECODE_STAGE        = 0            ,
    parameter SUPPORT_DUAL_ISSUE        = 1            ,
    parameter SUPPORT_LOAD_BYPASS       = 1            ,
    parameter SUPPORT_MUL_BYPASS        = 1            ,
    parameter MULT_STAGES               = 2            ,
    parameter MEM_CACHE_ADDR_MIN        = 32'h80000000 ,
    parameter MEM_CACHE_ADDR_MAX        = 32'h8fffffff  
)
(
    input   wire                clk_i                  ,
    input   wire                rstn_i                 ,
    input   wire                intr_i                 ,
    input   wire[31:0]          reset_vector_i         ,
    input   wire[31:0]          cpu_id_i               ,
    //通过MMU访问I-Cache
    input   wire                mem_i_accept_i         ,         
    input   wire [63:0]         mem_i_inst_i           , 
    input   wire                mem_i_valid_i          , 
    input   wire                mem_i_error_i          , 
    output  wire                mem_i_rd_o             ,               
    output  wire [31:0]         mem_i_pc_o             ,                           
    output  wire                mem_i_flush_o          ,            
    output  wire                mem_i_invalidate_o     ,
    //通过MMU访问D-Cache
    input   wire [31:0]         mem_d_data_rd_i        ,         
    input   wire                mem_d_accept_i         ,         
    input   wire                mem_d_ack_i            ,     
    input   wire                mem_d_error_i          ,         
    input   wire [10:0]         mem_d_resp_tag_i       , 
    output  wire [31:0]         mem_d_addr_o           ,     
    output  wire [31:0]         mem_d_data_wr_o        ,     
    output  wire                mem_d_rd_o             , 
    output  wire [ 3:0]         mem_d_wr_o             , 
    output  wire                mem_d_cacheable_o      ,         
    output  wire [10:0]         mem_d_req_tag_o        ,     
    output  wire                mem_d_invalidate_o     ,         
    output  wire                mem_d_writeback_o      ,         
    output  wire                mem_d_flush_o
);
//**********mmu_o -> frontend_i **********/
    wire            mmu_ifetch_accept_w;     
    wire [63:0]     mmu_ifetch_inst_w;       
    wire            mmu_ifetch_valid_w;      
    wire            mmu_ifetch_error_w;      
    wire            fetch_in_fault_w;  
//**********frontendu_o -> mmu_i **********//       
    wire            mmu_ifetch_rd_w;         
    wire [31:0]     mmu_ifetch_pc_w;         
    wire            mmu_ifetch_flush_w;      
    wire            mmu_ifetch_invalidate_w; 
    wire [ 1:0]     fetch_in_priv_w;
/**********frontend_o -> issue_i **********/
    //预译码信息
    wire [31:0]     fetch0_instr_w;         
    wire            fecth0_valid_w;         
    wire [31:0]     fetch0_pc_w;            
    wire            fetch0_fault_fetch_w;   
    wire            fetch0_fault_page_w;    
    wire            fetch0_instr_invalid_w; 
    wire            fetch0_instr_exec_w;    
    wire            fetch0_instr_lsu_w;     
    wire            fetch0_instr_branch_w;  
    wire            fetch0_instr_mul_w;     
    wire            fetch0_instr_div_w;     
    wire            fetch0_instr_csr_w;    
    wire            fetch0_instr_rs1_valid_w;
    wire            fetch0_instr_rs2_valid_w; 
    wire            fetch0_instr_rd_valid_w;
    wire [31:0]     fetch1_instr_w;         
    wire            fecth1_valid_w;         
    wire [31:0]     fetch1_pc_w;            
    wire            fetch1_fault_fetch_w;   
    wire            fetch1_fault_page_w;    
    wire            fetch1_instr_invalid_w; 
    wire            fetch1_instr_exec_w;    
    wire            fetch1_instr_lsu_w;     
    wire            fetch1_instr_branch_w;  
    wire            fetch1_instr_mul_w;     
    wire            fetch1_instr_div_w;     
    wire            fetch1_instr_csr_w;  
    wire            fetch1_instr_rs1_valid_w;
    wire            fetch1_instr_rs2_valid_w;    
    wire            fetch1_instr_rd_valid_w;
/**********issue_o -> frontend_i**********/
    //取到的指令被issue接收 用于握手
    wire            fetch0_accept_w;
    wire            fetch1_accept_w;
    //issue发生的分支跳转
    wire            branch_request_w;
    wire [31:0]     branch_pc_w;     
    wire [ 1:0]     branch_priv_w;   
/**********issue_o -> frontend_i(npc)**********/
    //用于更新分支预测器的数据
    wire            branch_info_request_w;     
    wire            branch_info_is_taken_w;    
    wire            branch_info_is_not_taken_w;
    wire            branch_info_is_call_w;     
    wire            branch_info_is_ret_w;      
    wire            branch_info_is_jmp_w;      
    wire [31:0]     branch_info_source_w;      
    wire [31:0]     branch_info_pc_w;          
/**********issue_o -> exec_i(npc)**********/
    //预译码结果给执行模块进一步译码
    wire            exec0_opcode_valid_w;
    wire [31:0]     opcode0_opcode_w;    
    wire [31:0]     opcode0_pc_w;        
    wire            opcode0_invalid_w;   
    wire [ 4:0]     opcode0_rd_idx_w;    
    wire [ 4:0]     opcode0_ra_idx_w;    
    wire [ 4:0]     opcode0_rb_idx_w;    
    wire [31:0]     opcode0_ra_operand_w;
    wire [31:0]     opcode0_rb_operand_w;
    wire            exec0_hold_w;        
    wire            exec1_opcode_valid_w;
    wire [31:0]     opcode1_opcode_w;    
    wire [31:0]     opcode1_pc_w;        
    wire            opcode1_invalid_w;   
    wire [ 4:0]     opcode1_rd_idx_w;    
    wire [ 4:0]     opcode1_ra_idx_w;    
    wire [ 4:0]     opcode1_rb_idx_w;    
    wire [31:0]     opcode1_ra_operand_w;
    wire [31:0]     opcode1_rb_operand_w;
    wire            exec1_hold_w;        
/**********exec_o -> issue_i(npc)**********/
    //将实际的运算结果，分支跳转结果返回issue
    wire [31:0]     writeback_exec0_value_w;    
    wire            branch_exec0_request_w;     
    wire            branch_exec0_is_taken_w;    
    wire            branch_exec0_is_not_taken_w;
    wire [31:0]     branch_exec0_pc_w;          
    wire [31:0]     branch_exec0_source_w;      
    wire            branch_exec0_is_call_w;     
    wire            branch_exec0_is_ret_w;      
    wire            branch_exec0_is_jmp_w;      
    wire            branch_d_exec0_request_w;   
    wire [31:0]     branch_d_exec0_pc_w;        
    wire [ 1:0]     branch_d_exec0_priv_w;   
    wire [31:0]     writeback_exec1_value_w;    
    wire            branch_exec1_request_w;     
    wire            branch_exec1_is_taken_w;    
    wire            branch_exec1_is_not_taken_w;
    wire [31:0]     branch_exec1_pc_w;          
    wire [31:0]     branch_exec1_source_w;      
    wire            branch_exec1_is_call_w;     
    wire            branch_exec1_is_ret_w;      
    wire            branch_exec1_is_jmp_w;      
    wire            branch_d_exec1_request_w;   
    wire [31:0]     branch_d_exec1_pc_w;        
    wire [ 1:0]     branch_d_exec1_priv_w; 
/**********issue_o -> mul_i**********/
    //用于解码和计算乘法
    wire            mul_opcode_valid_w;     
    wire [31:0]     mul_opcode_opcode_w;    
    wire [31:0]     mul_opcode_ra_operand_w;
    wire [31:0]     mul_opcode_rb_operand_w;  
    wire            mul_hold_w;
/**********mul_o -> issue_i**********/
    //乘法结果
    wire [31:0]     writeback_mul_value_w;
/**********div_o -> issue_i**********/
    //除法结果   
    wire            writeback_div_valid_w;
    wire [31:0]     writeback_div_value_w;
/**********issue_o -> div_i**********/
    wire            div_opcode_valid_w;
/**********issue_o -> lsu_i**********/
    wire            lsu_opcode_valid_w;     
    wire [31:0]     lsu_opcode_opcode_w;    
    wire [31:0]     lsu_opcode_pc_w;        
    wire [ 4:0]     lsu_opcode_rd_idx_w;    
    wire [ 4:0]     lsu_opcode_ra_idx_w;    
    wire [ 4:0]     lsu_opcode_rb_idx_w;    
    wire [31:0]     lsu_opcode_ra_operand_w;
    wire [31:0]     lsu_opcode_rb_operand_w;
/**********lsu_o -> mmu_i**********/
    wire [31:0]     lsu_in_addr_w;      
    wire [31:0]     lsu_in_data_wr_w;   
    wire            lsu_in_rd_w;        
    wire [ 3:0]     lsu_in_wr_w;        
    wire            lsu_in_cacheable_w; 
    wire [10:0]     lsu_in_req_tag_w;   
    wire            lsu_in_invalidate_w;
    wire            lsu_in_writeback_w; 
    wire            lsu_in_flush_w;     
/**********mmu_o -> lsu_i**********/
    wire            lsu_in_ack_w;        
    wire [10:0]     lsu_in_resp_tag_w;   
    wire            lsu_in_error_w;      
    wire [31:0]     lsu_in_data_rd_w;    
    wire            lsu_in_accept_w;     
    wire            lsu_in_store_fault_w;
    wire            lsu_in_load_fault_w; 
/**********lsu_o -> issue_i**********/
    wire            writeback_mem_valid_w;     
    wire [31:0]     writeback_mem_value_w;     
    wire [ 5:0]     writeback_mem_exception_w; 
    wire            lsu_stall_w;   
/**********issue_o -> csr_i**********/
    wire            csr_opcode_valid_w;     
    wire [31:0]     csr_opcode_opcode_w;    
    wire [31:0]     csr_opcode_pc_w;        
    wire            csr_opcode_invalid_w;   
    wire [ 4:0]     csr_opcode_rd_idx_w;    
    wire [ 4:0]     csr_opcode_ra_idx_w;    
    wire [ 4:0]     csr_opcode_rb_idx_w;    
    wire [31:0]     csr_opcode_ra_operand_w;
    wire [31:0]     csr_opcode_rb_operand_w;   
    wire            csr_writeback_write_w;  
    wire [11:0]     csr_writeback_waddr_w;  
    wire [31:0]     csr_writeback_wdata_w;  
    wire [ 5:0]     csr_writeback_exception_w;     
    wire [31:0]     csr_writeback_exception_pc_w;  
    wire [31:0]     csr_writeback_exception_addr_w; 
    wire            interrupt_inhibit_w;    
/**********csr_o -> issue_i**********/
    wire [31:0]     csr_result_e1_value_w;     
    wire            csr_result_e1_write_w;     
    wire [31:0]     csr_result_e1_wdata_w;     
    wire [ 5:0]     csr_result_e1_exception_w;    
    wire            branch_csr_request_w;
    wire [31:0]     branch_csr_pc_w;     
    wire [ 1:0]     branch_csr_priv_w; 
    wire            take_interrupt_w;  
/**********csr_o -> fronted_i**********/
    wire            ifence_w; 
frontend 
#(  
    .SUPPORT_BRANCH_PREDICTION (SUPPORT_BRANCH_PREDICTION),
    .GSHARE_ENABLE             (GSHARE_ENABLE            ),
    .PHT_ENABLE                (PHT_ENABLE               ),
    .RAS_ENABLE                (RAS_ENABLE               ),
    .NUM_PHT_ENTRIES           (NUM_PHT_ENTRIES          ),
    .NUM_PHT_ENTRIES_W         (NUM_PHT_ENTRIES_W        ),
    .NUM_RAS_ENTRIES           (NUM_RAS_ENTRIES          ),
    .NUM_RAS_ENTRIES_W         (NUM_RAS_ENTRIES_W        ),
    .NUM_BTB_ENTRIES           (NUM_BTB_ENTRIES          ),
    .NUM_BTB_ENTRIES_W         (NUM_BTB_ENTRIES_W        ),
    .SUPPORT_MMU               (SUPPORT_MMU              ),
    .SUPPORT_MULDIV            (SUPPORT_MULDIV           ),
    .EXTRA_DECODE_STAGE        (EXTRA_DECODE_STAGE       )
)
u_frontend
(
    .clk_i                      (clk_i),
    .rstn_i                     (rstn_i),
    .fetch_invalidate_i         (ifence_w                   ),//from CSR
//*********************************from issue*******************************//
    .fetch0_accept_i            (fetch0_accept_w            ),
    .fetch1_accept_i            (fetch1_accept_w            ),
    //(clear error data)
    .branch_request_i           (branch_request_w           ),//issue发现分支预测跳转错误
    .branch_pc_i                (branch_pc_w                ),
    .branch_priv_i              (branch_priv_w              ),
    //from issue to npc 用于分支预测学习
    .branch_info_request_i      (branch_info_request_w      ), 
    .branch_info_is_taken_i     (branch_info_is_taken_w     ),
    .branch_info_is_not_taken_i (branch_info_is_not_taken_w ), 
    .branch_info_source_i       (branch_info_source_w       ),
    .branch_info_is_call_i      (branch_info_is_call_w      ),
    .branch_info_is_ret_i       (branch_info_is_ret_w       ),
    .branch_info_is_jmp_i       (branch_info_is_jmp_w       ),
    .branch_info_pc_i           (branch_info_pc_w           ),
    //fetch通过MMU从i-cache读取数据
    .icache_accept_i            (mem_i_accept_i             ),
    .icache_inst_i              (mem_i_inst_i               ),
    .icache_valid_i             (mem_i_valid_i              ),
    .icache_error_i             (mem_i_error_i              ),
    .icache_page_fault_i        (1'b0                       ),
    .icache_rd_o                (mem_i_rd_o                 ),
    .icache_pc_o                (mem_i_pc_o                 ),   
    .icache_priv_o              (            ),
    .icache_flush_o             (mem_i_flush_o              ),
    .icache_invalidate_o        (mem_i_invalidate_o         ),
    //from decode to issue  
    .fetch0_instr_o             (fetch0_instr_w             ),   
    .fecth0_valid_o             (fecth0_valid_w             ),
    .fetch0_pc_o                (fetch0_pc_w                ),
    .fetch0_fault_fetch_o       (fetch0_fault_fetch_w       ),
    .fetch0_fault_page_o        (fetch0_fault_page_w        ),
    .fetch0_instr_invalid_o     (fetch0_instr_invalid_w     ),
    .fetch0_instr_exec_o        (fetch0_instr_exec_w        ),
    .fetch0_instr_lsu_o         (fetch0_instr_lsu_w         ),
    .fetch0_instr_branch_o      (fetch0_instr_branch_w      ),
    .fetch0_instr_mul_o         (fetch0_instr_mul_w         ),
    .fetch0_instr_div_o         (fetch0_instr_div_w         ),
    .fetch0_instr_csr_o         (fetch0_instr_csr_w         ),
    .fetch0_instr_rs1_valid_o   (fetch0_instr_rs1_valid_w   ),
    .fetch0_instr_rs2_valid_o   (fetch0_instr_rs2_valid_w   ),
    .fetch0_instr_rd_valid_o    (fetch0_instr_rd_valid_w    ),
    .fetch1_instr_o             (fetch1_instr_w             ),
    .fecth1_valid_o             (fecth1_valid_w             ),
    .fetch1_pc_o                (fetch1_pc_w                ),
    .fetch1_fault_fetch_o       (fetch1_fault_fetch_w       ),
    .fetch1_fault_page_o        (fetch1_fault_page_w        ),
    .fetch1_instr_invalid_o     (fetch1_instr_invalid_w     ),
    .fetch1_instr_exec_o        (fetch1_instr_exec_w        ),
    .fetch1_instr_lsu_o         (fetch1_instr_lsu_w         ),
    .fetch1_instr_branch_o      (fetch1_instr_branch_w      ),
    .fetch1_instr_mul_o         (fetch1_instr_mul_w         ),
    .fetch1_instr_div_o         (fetch1_instr_div_w         ),
    .fetch1_instr_csr_o         (fetch1_instr_csr_w         ),
    .fetch1_instr_rs1_valid_o   (fetch1_instr_rs1_valid_w   ),
    .fetch1_instr_rs2_valid_o   (fetch1_instr_rs2_valid_w   ),
    .fetch1_instr_rd_valid_o    (fetch1_instr_rd_valid_w    )  
);

issue 
#(
    .SUPPORT_MULDIV             (SUPPORT_MULDIV     ),
    .SUPPORT_DUAL_ISSUE         (SUPPORT_DUAL_ISSUE ),
    .SUPPORT_LOAD_BYPASS        (SUPPORT_LOAD_BYPASS),
    .SUPPORT_MUL_BYPASS         (SUPPORT_MUL_BYPASS )
)
u_issue
(
    .clk_i                           (clk_i                     ),
    .rstn_i                          (rstn_i                    ),
    //from frontend(decode)     
    .fetch0_instr_i                  (fetch0_instr_w            ),
    .fetch0_valid_i                  (fecth0_valid_w            ),
    .fetch0_pc_i                     (fetch0_pc_w               ),
    .fetch0_fault_fetch_i            (fetch0_fault_fetch_w      ),
    .fetch0_fault_page_i             (fetch0_fault_page_w       ),
    .fetch0_instr_invalid_i          (fetch0_instr_invalid_w    ),
    .fetch0_instr_exec_i             (fetch0_instr_exec_w       ),
    .fetch0_instr_lsu_i              (fetch0_instr_lsu_w        ),
    .fetch0_instr_branch_i           (fetch0_instr_branch_w     ),
    .fetch0_instr_mul_i              (fetch0_instr_mul_w        ),
    .fetch0_instr_div_i              (fetch0_instr_div_w        ),
    .fetch0_instr_csr_i              (fetch0_instr_csr_w        ),
    .fetch0_instr_rs1_valid_i        (fetch0_instr_rs1_valid_w  ),
    .fetch0_instr_rs2_valid_i        (fetch0_instr_rs2_valid_w  ),
    .fetch0_instr_rd_valid_i         (fetch0_instr_rd_valid_w   ),
    .fetch1_instr_i                  (fetch1_instr_w            ),
    .fetch1_valid_i                  (fecth1_valid_w            ),
    .fetch1_pc_i                     (fetch1_pc_w               ),
    .fetch1_fault_fetch_i            (fetch1_fault_fetch_w      ),
    .fetch1_fault_page_i             (fetch1_fault_page_w       ),
    .fetch1_instr_invalid_i          (fetch1_instr_invalid_w    ),
    .fetch1_instr_exec_i             (fetch1_instr_exec_w       ),
    .fetch1_instr_lsu_i              (fetch1_instr_lsu_w        ),
    .fetch1_instr_branch_i           (fetch1_instr_branch_w     ),
    .fetch1_instr_mul_i              (fetch1_instr_mul_w        ),
    .fetch1_instr_div_i              (fetch1_instr_div_w        ),
    .fetch1_instr_csr_i              (fetch1_instr_csr_w        ),
    .fetch1_instr_rs1_valid_i        (fetch1_instr_rs1_valid_w  ),
    .fetch1_instr_rs2_valid_i        (fetch1_instr_rs2_valid_w  ),
    .fetch1_instr_rd_valid_i         (fetch1_instr_rd_valid_w   ),
    //from exec0    
    .writeback_exec0_value_i         (writeback_exec0_value_w    ),//前馈
    .branch_exec0_request_i          (branch_exec0_request_w     ),
    .branch_exec0_is_taken_i         (branch_exec0_is_taken_w    ),
    .branch_exec0_is_not_taken_i     (branch_exec0_is_not_taken_w),
    .branch_exec0_pc_i               (branch_exec0_pc_w          ),
    .branch_exec0_source_i           (branch_exec0_source_w      ),
    .branch_exec0_is_call_i          (branch_exec0_is_call_w     ),
    .branch_exec0_is_ret_i           (branch_exec0_is_ret_w      ),
    .branch_exec0_is_jmp_i           (branch_exec0_is_jmp_w      ),
    .branch_d_exec0_request_i        (branch_d_exec0_request_w   ),
    .branch_d_exec0_pc_i             (branch_d_exec0_pc_w        ),
    .branch_d_exec0_priv_i           (branch_d_exec0_priv_w      ),               
    //from exec1   
    .writeback_exec1_value_i         (writeback_exec1_value_w    ),//前馈
    .branch_exec1_request_i          (branch_exec1_request_w     ),
    .branch_exec1_is_taken_i         (branch_exec1_is_taken_w    ),
    .branch_exec1_is_not_taken_i     (branch_exec1_is_not_taken_w),
    .branch_exec1_pc_i               (branch_exec1_pc_w          ),
    .branch_exec1_source_i           (branch_exec1_source_w      ),
    .branch_exec1_is_call_i          (branch_exec1_is_call_w     ),
    .branch_exec1_is_ret_i           (branch_exec1_is_ret_w      ),
    .branch_exec1_is_jmp_i           (branch_exec1_is_jmp_w      ),
    .branch_d_exec1_request_i        (branch_d_exec1_request_w   ),
    .branch_d_exec1_pc_i             (branch_d_exec1_pc_w        ),
    .branch_d_exec1_priv_i           (branch_d_exec1_priv_w      ),                     
    //from CSR  
    .branch_csr_request_i            (branch_csr_request_w       ),
    .branch_csr_pc_i                 (branch_csr_pc_w            ),
    .branch_csr_priv_i               (branch_csr_priv_w          ),
    //bypass data 
    .writeback_mul_value_i           (writeback_mul_value_w      ), 
    .writeback_div_valid_i           (writeback_div_valid_w      ),
    .writeback_div_value_i           (writeback_div_value_w      ),
    .writeback_mem_valid_i           (writeback_mem_valid_w      ),
    .writeback_mem_value_i           (writeback_mem_value_w      ),
    .writeback_mem_exception_i       (writeback_mem_exception_w  ),
    .lsu_stall_i                     (lsu_stall_w                ),

    .csr_result_value_e1_i           (csr_result_e1_value_w     ),    
    .csr_result_write_e1_i           (csr_result_e1_write_w     ),    
    .csr_result_wdata_e1_i           (csr_result_e1_wdata_w     ),    
    .csr_result_exception_e1_i       (csr_result_e1_exception_w ),

    .take_interrupt_i                (take_interrupt_w          ),  
//*********************************to frontend*******************************//
//branch_info_request是执行阶段确认后的分支结果,为了准确更新分支预测器，有1～2cycle延迟。
//branch_request是发现取指错误，马上让前级更新纠错，为了迅速减少性能损失。无延迟。
    //to fetch/decode
    .fetch0_accept_o                 (fetch0_accept_w           ),
    .fetch1_accept_o                 (fetch1_accept_w           ),
    .branch_request_o                (branch_request_w          ), 
    .branch_pc_o                     (branch_pc_w               ),
    .branch_priv_o                   (branch_priv_w             ),
    //to npc用于分支预测学习    
    .branch_info_request_o           (branch_info_request_w     ),
    .branch_info_is_taken_o          (branch_info_is_taken_w    ),
    .branch_info_is_not_taken_o      (branch_info_is_not_taken_w),
    .branch_info_is_call_o           (branch_info_is_call_w     ),
    .branch_info_is_ret_o            (branch_info_is_ret_w      ),
    .branch_info_is_jmp_o            (branch_info_is_jmp_w      ),
    .branch_info_source_o            (branch_info_source_w      ),
    .branch_info_pc_o                (branch_info_pc_w          ),
    
    .div_opcode_valid_o              (div_opcode_valid_w  ),
    //把预译码模块的信息进一步译码，传到执行模块，组合逻辑无延迟
    .exec0_opcode_valid_o            (exec0_opcode_valid_w),
    .opcode0_opcode_o                (opcode0_opcode_w    ),
    .opcode0_pc_o                    (opcode0_pc_w        ),
    .opcode0_invalid_o               (opcode0_invalid_w   ),
    .opcode0_rd_idx_o                (opcode0_rd_idx_w    ),
    .opcode0_ra_idx_o                (opcode0_ra_idx_w    ),
    .opcode0_rb_idx_o                (opcode0_rb_idx_w    ),
    .opcode0_ra_operand_o            (opcode0_ra_operand_w),
    .opcode0_rb_operand_o            (opcode0_rb_operand_w),
    .exec0_hold_o                    (exec0_hold_w        ),
    .exec1_opcode_valid_o            (exec1_opcode_valid_w),
    .opcode1_opcode_o                (opcode1_opcode_w    ),
    .opcode1_pc_o                    (opcode1_pc_w        ),
    .opcode1_invalid_o               (opcode1_invalid_w   ),
    .opcode1_rd_idx_o                (opcode1_rd_idx_w    ),
    .opcode1_ra_idx_o                (opcode1_ra_idx_w    ),
    .opcode1_rb_idx_o                (opcode1_rb_idx_w    ), 
    .opcode1_ra_operand_o            (opcode1_ra_operand_w),     
    .opcode1_rb_operand_o            (opcode1_rb_operand_w),     
    .exec1_hold_o                    (exec1_hold_w        ),   
    //to LSU   
    .lsu_opcode_valid_o              (lsu_opcode_valid_w     ),
    .lsu_opcode_opcode_o             (lsu_opcode_opcode_w    ),
    .lsu_opcode_ra_operand_o         (lsu_opcode_ra_operand_w),
    .lsu_opcode_rb_operand_o         (lsu_opcode_rb_operand_w),
    //to MUL
    .mul_opcode_valid_o              (mul_opcode_valid_w     ),    
    .mul_opcode_opcode_o             (mul_opcode_opcode_w    ),
    .mul_opcode_ra_operand_o         (mul_opcode_ra_operand_w),
    .mul_opcode_rb_operand_o         (mul_opcode_rb_operand_w),
    .mul_hold_o                      (mul_hold_w             ),
    //to CSR   
    .csr_opcode_valid_o              (csr_opcode_valid_w            ), 
    .csr_opcode_opcode_o             (csr_opcode_opcode_w           ),
    .csr_opcode_pc_o                 (csr_opcode_pc_w               ),
    .csr_opcode_rd_idx_o             (csr_opcode_rd_idx_w           ),
    .csr_opcode_ra_idx_o             (csr_opcode_ra_idx_w           ),
    .csr_opcode_rb_idx_o             (csr_opcode_rb_idx_w           ),
    .csr_opcode_ra_operand_o         (csr_opcode_ra_operand_w       ),
    .csr_opcode_rb_operand_o         (csr_opcode_rb_operand_w       ),
    .csr_opcode_invalid_o            (csr_opcode_invalid_w          ),
    .csr_writeback_write_o           (csr_writeback_write_w         ),
    .csr_writeback_waddr_o           (csr_writeback_waddr_w         ),
    .csr_writeback_wdata_o           (csr_writeback_wdata_w         ),
    .csr_writeback_exception_o       (csr_writeback_exception_w     ),
    .csr_writeback_exception_pc_o    (csr_writeback_exception_pc_w  ),
    .csr_writeback_exception_addr_o  (csr_writeback_exception_addr_w), 

    .interrupt_inhibit_o             (interrupt_inhibit_w)

);

exec u0_exec 
(
    .clk_i                   (clk_i                      ),
    .rstn_i                  (rstn_i                     ),

    .opcode_valid_i          (exec0_opcode_valid_w       ),
    .opcode_opcode_i         (opcode0_opcode_w           ),
    .opcode_pc_i             (opcode0_pc_w               ),
    .opcode_invalid_i        (opcode0_invalid_w          ),
    .opcode_rd_idx_i         (opcode0_rd_idx_w           ),
    .opcode_ra_idx_i         (opcode0_ra_idx_w           ),
    .opcode_rb_idx_i         (opcode0_rb_idx_w           ),
    .opcode_ra_operand_i     (opcode0_ra_operand_w       ),
    .opcode_rb_operand_i     (opcode0_rb_operand_w       ), 
    .hold_i                  (exec0_hold_w               ),
    //都是组合逻辑打一拍输出
    .writeback_value_o       (writeback_exec0_value_w    ),
    .branch_request_o        (branch_exec0_request_w     ),//分支指令标志
    .branch_is_taken_o       (branch_exec0_is_taken_w    ),    
    .branch_is_not_taken_o   (branch_exec0_is_not_taken_w),
    .branch_pc_o             (branch_exec0_pc_w          ),          
    .branch_source_o         (branch_exec0_source_w      ),      
    .branch_call_o           (branch_exec0_is_call_w     ),        
    .branch_ret_o            (branch_exec0_is_ret_w      ),         
    .branch_jmp_o            (branch_exec0_is_jmp_w      ),
    //组合逻辑的输出，没有打一拍  
    .branch_d_request_o      (branch_d_exec0_request_w   ),
    .branch_d_pc_o           (branch_d_exec0_pc_w        ),
    .branch_d_priv_o         (branch_d_exec0_priv_w      ) 
);  

exec u1_exec 
(
    .clk_i                   (clk_i                      ),
    .rstn_i                  (rstn_i                     ),

    .opcode_valid_i          (exec1_opcode_valid_w       ),
    .opcode_opcode_i         (opcode1_opcode_w           ),
    .opcode_pc_i             (opcode1_pc_w               ),
    .opcode_invalid_i        (opcode1_invalid_w          ),
    .opcode_rd_idx_i         (opcode1_rd_idx_w           ),
    .opcode_ra_idx_i         (opcode1_ra_idx_w           ),
    .opcode_rb_idx_i         (opcode1_rb_idx_w           ),
    .opcode_ra_operand_i     (opcode1_ra_operand_w       ),
    .opcode_rb_operand_i     (opcode1_rb_operand_w       ), 
    .hold_i                  (exec1_hold_w               ),
    //都是组合逻辑打一拍输出
    .writeback_value_o       (writeback_exec1_value_w    ),
    .branch_request_o        (branch_exec1_request_w     ),//分支指令标志
    .branch_is_taken_o       (branch_exec1_is_taken_w    ),    
    .branch_is_not_taken_o   (branch_exec1_is_not_taken_w),
    .branch_pc_o             (branch_exec1_pc_w          ),          
    .branch_source_o         (branch_exec1_source_w      ),      
    .branch_call_o           (branch_exec1_is_call_w     ),        
    .branch_ret_o            (branch_exec1_is_ret_w      ),         
    .branch_jmp_o            (branch_exec1_is_jmp_w      ),
    //组合逻辑的输出，没有打一拍    
    .branch_d_request_o      (branch_d_exec1_request_w   ),
    .branch_d_pc_o           (branch_d_exec1_pc_w        ),
    .branch_d_priv_o         (branch_d_exec1_priv_w      ) 
); 


multiplier 
#(
    .MULT_STAGES    (MULT_STAGES)//计算周期可以是2或3
)
u_multiplier
(
    .clk_i               (clk_i                  ),
    .rstn_i              (rstn_i                 ),
    .opcode_valid_i      (mul_opcode_valid_w     ),
    .opcode_opcode_i     (mul_opcode_opcode_w    ),
    .opcode_ra_operand_i (mul_opcode_ra_operand_w),
    .opcode_rb_operand_i (mul_opcode_rb_operand_w),
    .hold_i              (mul_hold_w             ),

    .writeback_value_o   (writeback_mul_value_w  )
);

divider u_divider
(
    .clk_i               (clk_i),
    .rstn_i              (rstn_i),
    .opcode_valid_i      (div_opcode_valid_w     ),
    .opcode_opcode_i     (opcode0_opcode_w       ),
    .opcode_ra_operand_i (opcode0_ra_operand_w   ),
    .opcode_rb_operand_i (opcode0_rb_operand_w   ),

    .writeback_valid_o   (writeback_div_valid_w  ),
    .writeback_value_o   (writeback_div_value_w  )
);

lsu 
#(
    .MEM_CACHE_ADDR_MIN(MEM_CACHE_ADDR_MIN) ,
    .MEM_CACHE_ADDR_MAX(MEM_CACHE_ADDR_MAX)
)
u_lsu
(
    .clk_i                   (clk_i                     ),
    .rstn_i                  (rstn_i                    ),
    .opcode_valid_i          (lsu_opcode_valid_w        ),     
    .opcode_opcode_i         (lsu_opcode_opcode_w       ),
    .opcode_ra_operand_i     (lsu_opcode_ra_operand_w   ),
    .opcode_rb_operand_i     (lsu_opcode_rb_operand_w   ),
    //from mmu(D-Cache)  
    .mem_data_rd_i           (mem_d_data_rd_i           ), 
    .mem_accept_i            (mem_d_accept_i            ), 
    .mem_ack_i               (mem_d_ack_i               ), 
    .mem_error_i             (mem_d_error_i             ), 
    .mem_resp_tag_i          (mem_d_resp_tag_i          ), 
    .mem_load_fault_i        (1'b0                      ), 
    .mem_store_fault_i       (1'b0                      ),

    .mem_addr_o              (mem_d_addr_o              ),        
    .mem_data_wr_o           (mem_d_data_wr_o           ),        
    .mem_rd_o                (mem_d_rd_o                ),    
    .mem_wr_o                (mem_d_wr_o                ),    
    .mem_cacheable_o         (mem_d_cacheable_o         ),        
    .mem_req_tag_o           (mem_d_req_tag_o           ),        
    .mem_invalidate_o        (mem_d_invalidate_o        ),            
    .mem_writeback_o         (mem_d_writeback_o         ),        
    .mem_flush_o             (mem_d_flush_o             ), 
    //to issue  
    .writeback_valid_o       (writeback_mem_valid_w     ),
    .writeback_value_o       (writeback_mem_value_w     ),
    .writeback_exception_o   (writeback_mem_exception_w ),
    .stall_o                 (lsu_stall_w               )
);
csr 
#(
    .SUPPORT_MULDIV(SUPPORT_MULDIV),
    .SUPPORT_SUPER (SUPPORT_SUPER)
)u_csr
(
    .clk_i                           (clk_i     ),
    .rstn_i                          (rstn_i    ),
    .intr_i                          (intr_i),//外部中断
    .cpu_id_i                        (cpu_id_i      ),
    .reset_vector_i                  (reset_vector_i),
    .interrupt_inhibit_i             (interrupt_inhibit_w),

    .opcode_valid_i                  (csr_opcode_valid_w     ),
    .opcode_opcode_i                 (csr_opcode_opcode_w    ),
    .opcode_pc_i                     (csr_opcode_pc_w        ),
    .opcode_invalid_i                (csr_opcode_invalid_w   ),
    .opcode_rd_idx_i                 (csr_opcode_rd_idx_w    ),
    .opcode_ra_idx_i                 (csr_opcode_ra_idx_w    ),
    .opcode_rb_idx_i                 (csr_opcode_rb_idx_w    ),
    .opcode_ra_operand_i             (csr_opcode_ra_operand_w),
    .opcode_rb_operand_i             (csr_opcode_rb_operand_w),

    .csr_writeback_write_i           (csr_writeback_write_w  ),
    .csr_writeback_waddr_i           (csr_writeback_waddr_w  ),
    .csr_writeback_wdata_i           (csr_writeback_wdata_w  ),
    .csr_writeback_exception_i       (csr_writeback_exception_w     ),
    .csr_writeback_exception_pc_i    (csr_writeback_exception_pc_w  ),
    .csr_writeback_exception_addr_i  (csr_writeback_exception_addr_w),

    .csr_result_e1_value_o           (csr_result_e1_value_w     ),
    .csr_result_e1_write_o           (csr_result_e1_write_w     ),
    .csr_result_e1_wdata_o           (csr_result_e1_wdata_w     ),
    .csr_result_e1_exception_o       (csr_result_e1_exception_w ),
    .branch_csr_request_o            (branch_csr_request_w),
    .branch_csr_pc_o                 (branch_csr_pc_w     ),
    .branch_csr_priv_o               (branch_csr_priv_w   ),
    .take_interrupt_o                (take_interrupt_w),

    .ifence_o                        (ifence_w),
    .mmu_priv_d_o                    (),
    .mmu_sum_o                       (),
    .mmu_mxr_o                       (),
    .mmu_flush_o                     (),
    .mmu_satp_o                      ()
);
endmodule