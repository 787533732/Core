`include "../core/define.v"
module csr 
#(
    parameter SUPPORT_MULDIV = 1,
    parameter SUPPORT_SUPER  = 0
) 
(
    input   wire                    clk_i                          ,
    input   wire                    rstn_i                         ,
    input   wire                    intr_i                         ,//外部中断
    input   wire [31:0]             cpu_id_i                        ,
    input   wire [31:0]             reset_vector_i                  ,
    input   wire                    interrupt_inhibit_i             ,

    input   wire                    opcode_valid_i                 ,
    input   wire [31:0]             opcode_opcode_i                ,
    input   wire [31:0]             opcode_pc_i                    ,
    input   wire                    opcode_invalid_i               ,
    input   wire [ 4:0]             opcode_rd_idx_i                ,
    input   wire [ 4:0]             opcode_ra_idx_i                ,
    input   wire [ 4:0]             opcode_rb_idx_i                ,
    input   wire [31:0]             opcode_ra_operand_i            ,
    input   wire [31:0]             opcode_rb_operand_i            ,

    input   wire                    csr_writeback_write_i           ,
    input   wire [11:0]             csr_writeback_waddr_i           ,
    input   wire [31:0]             csr_writeback_wdata_i           ,
    input   wire [ 5:0]             csr_writeback_exception_i       ,
    input   wire [31:0]             csr_writeback_exception_pc_i    ,
    input   wire [31:0]             csr_writeback_exception_addr_i  ,

    output  wire [31:0]             csr_result_e1_value_o           ,
    output  wire                    csr_result_e1_write_o           ,
    output  wire [31:0]             csr_result_e1_wdata_o           ,
    output  wire [ 5:0]             csr_result_e1_exception_o       ,
    output  wire                    branch_csr_request_o            ,
    output  wire [31:0]             branch_csr_pc_o                 ,
    output  wire [ 1:0]             branch_csr_priv_o               ,
    output  wire                    take_interrupt_o                ,

    output  wire                    ifence_o                        ,
    output  wire [ 1:0]             mmu_priv_d_o                    ,
    output  wire                    mmu_sum_o                       ,
    output  wire                    mmu_mxr_o                       ,
    output  wire                    mmu_flush_o                     ,
    output  wire [31:0]             mmu_satp_o                      
);
  
    wire fence_w  = opcode_valid_i && ((opcode_opcode_i & `INST_FENCE_MASK ) == `INST_FENCE );
    wire eret_w   = opcode_valid_i && ((opcode_opcode_i & `INST_ERET_MASK  ) == `INST_ERET  );
    wire ecall_w  = opcode_valid_i && ((opcode_opcode_i & `INST_ECALL_MASK ) == `INST_ECALL );
    wire ebreak_w = opcode_valid_i && ((opcode_opcode_i & `INST_EBREAK_MASK) == `INST_EBREAK);
    wire ifence_w = opcode_valid_i && ((opcode_opcode_i & `INST_IFENCE_MASK) == `INST_IFENCE);
    wire sfence_w = opcode_valid_i && ((opcode_opcode_i & `INST_SFENCE_MASK) == `INST_SFENCE);
    wire csrrw_w  = opcode_valid_i && ((opcode_opcode_i & `INST_CSRRW_MASK ) == `INST_CSRRW );
    wire csrrs_w  = opcode_valid_i && ((opcode_opcode_i & `INST_CSRRS_MASK ) == `INST_CSRRS );
    wire csrrc_w  = opcode_valid_i && ((opcode_opcode_i & `INST_CSRRC_MASK ) == `INST_CSRRC );
    wire csrrwi_w = opcode_valid_i && ((opcode_opcode_i & `INST_CSRRWI_MASK) == `INST_CSRRWI);
    wire csrrsi_w = opcode_valid_i && ((opcode_opcode_i & `INST_CSRRSI_MASK) == `INST_CSRRSI);
    wire csrrci_w = opcode_valid_i && ((opcode_opcode_i & `INST_CSRRCI_MASK) == `INST_CSRRCI);
    wire [ 1:0] eret_priv_w = opcode_opcode_i[29:28];

    wire [ 1:0] current_priv_w;
    reg  [ 1:0] csr_priv_r;
    reg         csr_readonly_r;
    reg         csr_write_r;
    reg         set_r;
    reg         clr_r;
    reg         csr_fault_r;
    reg  [31:0] data_r;
    

    always @(*) begin
        set_r          = csrrw_w | csrrwi_w | csrrs_w | csrrsi_w;
        clr_r          = csrrw_w | csrrwi_w | csrrc_w | csrrci_w;
    
        csr_priv_r     = opcode_opcode_i[29:28];
        csr_readonly_r = (opcode_opcode_i[31:30] == 2'b11);
        csr_write_r    = csrrw_w | csrrwi_w | (opcode_ra_idx_i != 5'b0);
        //启用supper才需要用到
        csr_fault_r    = 1'b0;

        data_r         = (csrrwi_w | csrrsi_w | csrrci_w) ? {27'b0, opcode_ra_idx_i} : opcode_ra_operand_i;
    end

    wire satp_update_w = (opcode_valid_i && (set_r || clr_r) && csr_write_r && (opcode_opcode_i[31:20] == `CSR_SATP));

    //-----------------------------------------------------------------
    // CSR register file
    //-----------------------------------------------------------------
    wire [31:0] misa_w = SUPPORT_MULDIV ? (`MISA_RV32 | `MISA_RVI | `MISA_RVM): (`MISA_RV32 | `MISA_RVI);//RV32IM

    wire [31:0] csr_rdata_w;

    wire        csr_branch_w;
    wire [31:0] csr_target_w;

    wire [31:0] interrupt_w;
    wire [31:0] status_reg_w;
    wire [31:0] satp_reg_w;

    csr_regfile
    #( 
        .SUPPORT_MTIMECMP(1)            ,
        .SUPPORT_SUPER(SUPPORT_SUPER) 
    )
    u_csrfile
    (
         .clk_i(clk_i)
        ,.rstn_i(rstn_i)

        ,.ext_intr_i(intr_i)
        ,.timer_intr_i(1'b0)
        ,.cpu_id_i(cpu_id_i)
        ,.misa_i(misa_w)

        // Issue
        ,.csr_ren_i(opcode_valid_i)
        ,.csr_raddr_i(opcode_opcode_i[31:20])
        ,.csr_rdata_o(csr_rdata_w)

        // Exception (WB)
        ,.exception_i(csr_writeback_exception_i)
        ,.exception_pc_i(csr_writeback_exception_pc_i)
        ,.exception_addr_i(csr_writeback_exception_addr_i)

        // CSR register writes (WB)
        ,.csr_waddr_i(csr_writeback_write_i ? csr_writeback_waddr_i : 12'b0)
        ,.csr_wdata_i(csr_writeback_wdata_i)

        // CSR branches
        ,.csr_branch_o(csr_branch_w)
        ,.csr_target_o(csr_target_w)

        // Various CSR registers
        ,.priv_o(current_priv_w)
        ,.status_o(status_reg_w)//status register
        ,.satp_o(satp_reg_w)//32'b0

        // Masked interrupt output
        ,.interrupt_o(interrupt_w)
    );


    //-----------------------------------------------------------------
    // CSR Read Result (E1) / Early exceptions
    //-----------------------------------------------------------------
    reg                     rd_valid_e1_q;
    reg [ 31:0]             rd_result_e1_q;
    reg [ 31:0]             csr_wdata_e1_q;
    reg [`EXCEPTION_W-1:0]  exception_e1_q;
    // Inappropriate xRET for the current exec priv level
    wire                    eret_fault_w = eret_w && (current_priv_w < eret_priv_w);



    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            rd_valid_e1_q   <= 1'b0;
            rd_result_e1_q  <= 32'b0;
            csr_wdata_e1_q  <= 32'b0;
            exception_e1_q  <= `EXCEPTION_W'b0;
        end
        else if(opcode_valid_i) begin
            rd_valid_e1_q   <= (set_r || clr_r) && ~csr_fault_r;
            // Invalid instruction / CSR access fault?
            // Record opcode for writing to csr_xtval later.
            if (opcode_invalid_i || csr_fault_r || eret_fault_w)
                rd_result_e1_q  <= opcode_opcode_i;
            else    
                rd_result_e1_q  <= csr_rdata_w;
            // E1 CSR exceptions
            if ((opcode_opcode_i & `INST_ECALL_MASK) == `INST_ECALL)
                exception_e1_q  <= `EXCEPTION_ECALL + {4'b0, current_priv_w};
            // xRET for priv level above this one - fault
            else if (eret_fault_w)
                exception_e1_q  <= `EXCEPTION_ILLEGAL_INSTRUCTION;
            else if ((opcode_opcode_i & `INST_ERET_MASK) == `INST_ERET)
                exception_e1_q  <= `EXCEPTION_ERET_U + {4'b0, eret_priv_w};
            else if ((opcode_opcode_i & `INST_EBREAK_MASK) == `INST_EBREAK)
                exception_e1_q  <= `EXCEPTION_BREAKPOINT;
            else if (opcode_invalid_i || csr_fault_r)
                exception_e1_q  <= `EXCEPTION_ILLEGAL_INSTRUCTION;
            // Fence / MMU settings cause a pipeline flush
            else if (satp_update_w || ifence_w || sfence_w)
                exception_e1_q  <= `EXCEPTION_FENCE;
            else
                exception_e1_q  <= `EXCEPTION_W'b0;
            // Value to be written to CSR registers
            if (set_r && clr_r)
                csr_wdata_e1_q <= data_r;
            else if (set_r)
                csr_wdata_e1_q <= csr_rdata_w | data_r;
            else if (clr_r)
                csr_wdata_e1_q <= csr_rdata_w & ~data_r;
        end
        else begin
            rd_valid_e1_q   <= 1'b0;
            rd_result_e1_q  <= 32'b0;
            csr_wdata_e1_q  <= 32'b0;
            exception_e1_q  <= `EXCEPTION_W'b0;
        end
    end
    assign csr_result_e1_value_o     = rd_result_e1_q;
    assign csr_result_e1_write_o     = rd_valid_e1_q;
    assign csr_result_e1_wdata_o     = csr_wdata_e1_q;
    assign csr_result_e1_exception_o = exception_e1_q;

//-----------------------------------------------------------------
// Interrupt launch enable
//-----------------------------------------------------------------
    reg take_interrupt_q;

    always @ (posedge clk_i or negedge rstn_i)
    if (!rstn_i)
        take_interrupt_q    <= 1'b0;
    else
        take_interrupt_q    <= (|interrupt_w) & ~interrupt_inhibit_i;

    assign take_interrupt_o = take_interrupt_q;

//-----------------------------------------------------------------
// TLB flush
//-----------------------------------------------------------------
    reg tlb_flush_q;

    always @ (posedge clk_i or negedge rstn_i)
    if (!rstn_i)
        tlb_flush_q <= 1'b0;
    else
        tlb_flush_q <= satp_update_w || sfence_w;

//-----------------------------------------------------------------
// ifence
//-----------------------------------------------------------------
    reg ifence_q;

    always @ (posedge clk_i or negedge rstn_i)
    if (!rstn_i)
        ifence_q    <= 1'b0;
    else
        ifence_q    <= ifence_w;

    assign ifence_o = ifence_q;

//-----------------------------------------------------------------
// Execute - Branch operations
//-----------------------------------------------------------------
    reg        branch_q;
    reg [31:0] branch_target_q;
    reg        reset_q;

    always @ (posedge clk_i or negedge rstn_i)
    if (!rstn_i)
    begin
        branch_target_q <= 32'b0;
        branch_q        <= 1'b0;
        reset_q         <= 1'b1;
    end
    else if (reset_q)
    begin
        branch_target_q <= reset_vector_i;
        branch_q        <= 1'b1;
        reset_q         <= 1'b0;
    end
    else
    begin
        branch_q        <= csr_branch_w;
        branch_target_q <= csr_target_w;
    end

    assign branch_csr_request_o = branch_q;
    assign branch_csr_pc_o      = branch_target_q;
    assign branch_csr_priv_o    = satp_reg_w[`SATP_MODE_R] ? current_priv_w : `PRIV_MACHINE;

    //-----------------------------------------------------------------
    // MMU
    //-----------------------------------------------------------------
    assign mmu_priv_d_o     = status_reg_w[`SR_MPRV_R] ? status_reg_w[`SR_MPP_R] : current_priv_w;
    assign mmu_satp_o       = satp_reg_w;
    assign mmu_flush_o      = tlb_flush_q;
    assign mmu_sum_o        = status_reg_w[`SR_SUM_R];
    assign mmu_mxr_o        = status_reg_w[`SR_MXR_R];



endmodule