`include "../core/define.v"
module csr_regfile
#(
    parameter SUPPORT_SUPER = 1,
    parameter SUPPORT_MTIMECMP = 1 
)
(
    input   wire                    clk_i           ,
    input   wire                    rstn_i          ,

    input   wire                    ext_intr_i      ,//外部中断
    input   wire                    timer_intr_i    ,//定时器中断
    input   wire [31:0]             cpu_id_i        ,
    input   wire [31:0]             misa_i          ,//ISA:RV32IM
    input   wire [ 5:0]             exception_i     ,
    input   wire [31:0]             exception_pc_i  ,
    input   wire [31:0]             exception_addr_i,
    //read port
    input   wire                    csr_ren_i       ,
    input   wire [11:0]             csr_raddr_i     ,
    output  wire [31:0]             csr_rdata_o     ,
    //write port
    input   wire [11:0]             csr_waddr_i     ,
    input   wire [31:0]             csr_wdata_i     ,
    //csr branch
    output  wire                    csr_branch_o    ,
    output  wire [31:0]             csr_target_o    ,
    // CSR registers
    output  wire [ 1:0]             priv_o          ,
    output  wire [31:0]             status_o        ,
    output  wire [31:0]             satp_o          ,

    output  wire [31:0]             interrupt_o
);
    
    // CSR - Machine
    reg [31:0]  csr_mepc_q;
    reg [31:0]  csr_mcause_q;
    reg [31:0]  csr_sr_q;
    reg [31:0]  csr_mtvec_q;
    reg [31:0]  csr_mip_q;
    reg [31:0]  csr_mie_q;
    reg [1:0]   csr_mpriv_q;
    reg [31:0]  csr_mcycle_q;
    reg [31:0]  csr_mcycle_h_q;
    reg [31:0]  csr_mscratch_q;
    reg [31:0]  csr_mtval_q;
    reg [31:0]  csr_mtimecmp_q;
    reg         csr_mtime_ie_q;
    reg [31:0]  csr_medeleg_q;
    reg [31:0]  csr_mideleg_q;


//-----------------------------------------------------------------
// Masked Interrupts
//-----------------------------------------------------------------
    reg [31:0] irq_pending_r;
    reg [31:0] irq_masked_r;
    reg [ 1:0] irq_priv_r;

    always @(*) begin
        if(SUPPORT_SUPER) begin
            
        end
        else begin
            irq_pending_r = (csr_mip_q & csr_mie_q);//mie mip按位与得出正在处理的中断
            irq_masked_r  = csr_sr_q[`SR_MIE_R] ? irq_pending_r : 32'b0;//Status Resister对应位如果不使能则屏蔽中断
            irq_priv_r    = `PRIV_MACHINE;
        end
    end
    reg [ 1:0] irq_priv_q;
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            irq_priv_q <= `PRIV_MACHINE;
        else if(|irq_masked_r)//中断产生
            irq_priv_q <= irq_priv_r;
    end
    assign interrupt_o = irq_masked_r;

    reg csr_mip_upd_q;

    always @ (posedge clk_i or negedge rstn_i)
    if (!rstn_i)
        csr_mip_upd_q <= 1'b0;
    else if (csr_ren_i && csr_raddr_i == `CSR_MIP)
        csr_mip_upd_q <= 1'b1;
    else if (csr_waddr_i == `CSR_MIP || (|exception_i))
        csr_mip_upd_q <= 1'b0;

    wire buffer_mip_w = (csr_ren_i && csr_raddr_i == `CSR_MIP) | csr_mip_upd_q;

//-----------------------------------------------------------------
// CSR Read Port
//-----------------------------------------------------------------
    reg [31:0] rdata_r;
    always @(*) begin
        rdata_r = 32'b0;
        case (csr_raddr_i)
        // CSR - Machine
        `CSR_MSCRATCH: rdata_r = csr_mscratch_q & `CSR_MSCRATCH_MASK;
        `CSR_MEPC:     rdata_r = csr_mepc_q & `CSR_MEPC_MASK;
        `CSR_MTVEC:    rdata_r = csr_mtvec_q & `CSR_MTVEC_MASK;
        `CSR_MCAUSE:   rdata_r = csr_mcause_q & `CSR_MCAUSE_MASK;
        `CSR_MTVAL:    rdata_r = csr_mtval_q & `CSR_MTVAL_MASK;
        `CSR_MSTATUS:  rdata_r = csr_sr_q & `CSR_MSTATUS_MASK;
        `CSR_MIP:      rdata_r = csr_mip_q & `CSR_MIP_MASK;
        `CSR_MIE:      rdata_r = csr_mie_q & `CSR_MIE_MASK;
        `CSR_MCYCLE,
        `CSR_MTIME:    rdata_r = csr_mcycle_q;
        `CSR_MTIMEH:   rdata_r = csr_mcycle_h_q;
        `CSR_MHARTID:  rdata_r = cpu_id_i;
        `CSR_MISA:     rdata_r = misa_i;
        `CSR_MEDELEG:  rdata_r = 32'b0;
        `CSR_MIDELEG:  rdata_r = 32'b0;
        `CSR_MTIMECMP: rdata_r = 32'b0;
        default     :  rdata_r = 32'b0;
        endcase
    end

    assign csr_rdata_o = rdata_r;
    assign priv_o      = csr_mpriv_q;
    assign status_o    = csr_sr_q;
    assign satp_o      = 32'b0;
//-----------------------------------------------------------------
// CSR register next state
//-----------------------------------------------------------------
// CSR - Machine
    reg [31:0]  csr_mepc_r;
    reg [31:0]  csr_mcause_r;
    reg [31:0]  csr_mtval_r;
    reg [31:0]  csr_sr_r;
    reg [31:0]  csr_mtvec_r;
    reg [31:0]  csr_mip_r;
    reg [31:0]  csr_mie_r;
    reg [1:0]   csr_mpriv_r;
    reg [31:0]  csr_mcycle_r;
    reg [31:0]  csr_mscratch_r;
    reg [31:0]  csr_mtimecmp_r;
    reg         csr_mtime_ie_r;
    reg [31:0]  csr_medeleg_r;
    reg [31:0]  csr_mideleg_r;

    reg [31:0]  csr_mip_next_q;
    reg [31:0]  csr_mip_next_r;

    wire is_exception_w = ((exception_i & `EXCEPTION_TYPE_MASK) == `EXCEPTION_EXCEPTION);

    always @(*)
    begin
        // CSR - Machine
        csr_mip_next_r  = csr_mip_next_q;
        csr_mepc_r      = csr_mepc_q;
        csr_sr_r        = csr_sr_q;
        csr_mcause_r    = csr_mcause_q;
        csr_mtval_r     = csr_mtval_q;
        csr_mtvec_r     = csr_mtvec_q;
        csr_mip_r       = csr_mip_q;
        csr_mie_r       = csr_mie_q;
        csr_mpriv_r     = csr_mpriv_q;
        csr_mscratch_r  = csr_mscratch_q;
        csr_mcycle_r    = csr_mcycle_q + 32'd1;
        csr_mtimecmp_r  = csr_mtimecmp_q;
        csr_mtime_ie_r  = csr_mtime_ie_q;
        csr_medeleg_r   = csr_medeleg_q;
        csr_mideleg_r   = csr_mideleg_q;
        // Interrupts
        if((exception_i & `EXCEPTION_TYPE_MASK) == `EXCEPTION_INTERRUPT) begin
            // Machine mode interrupts
            if(irq_priv_q == `PRIV_MACHINE) begin
                // Save interrupt / supervisor state
                csr_sr_r[`SR_MPIE_R] = csr_sr_r[`SR_MIE_R];
                csr_sr_r[`SR_MPP_R]  = csr_mpriv_q;
                // Disable interrupts and enter supervisor mode
                csr_sr_r[`SR_MIE_R]  = 1'b0;
                // Raise priviledge to machine level
                csr_mpriv_r          = `PRIV_MACHINE;
                // Record interrupt source PC
                csr_mepc_r           = exception_pc_i;
                csr_mtval_r          = 32'b0;
                // Piority encoded interrupt cause
                if (interrupt_o[`IRQ_M_EXT])
                    csr_mcause_r = `MCAUSE_INTERRUPT + 32'd`IRQ_M_EXT;
            end
        end
        // Exception return
        else if(exception_i >= `EXCEPTION_ERET_U && exception_i <= `EXCEPTION_ERET_M) begin
            // MRET (return from machine)
            if(exception_i[1:0] == `PRIV_MACHINE) begin
                // Set privilege level to previous MPP
                csr_mpriv_r          = csr_sr_r[`SR_MPP_R];

                // Interrupt enable pop
                csr_sr_r[`SR_MIE_R]  = csr_sr_r[`SR_MPIE_R];
                csr_sr_r[`SR_MPIE_R] = 1'b1;

                // TODO: Set next MPP to user mode??
                csr_sr_r[`SR_MPP_R] = `SR_MPP_U;
            end
            // SRET (return from supervisor)
        end
        // Exception - handled in machine mode
        else if(is_exception_w) begin
            // Save interrupt / supervisor state
            csr_sr_r[`SR_MPIE_R] = csr_sr_r[`SR_MIE_R];
            csr_sr_r[`SR_MPP_R]  = csr_mpriv_q;
            // Disable interrupts and enter supervisor mode
            csr_sr_r[`SR_MIE_R]  = 1'b0;
            // Raise priviledge to machine level
            csr_mpriv_r  = `PRIV_MACHINE;
            // Record fault source PC
            csr_mepc_r   = exception_pc_i;
            // Bad address / PC
            case (exception_i)
            `EXCEPTION_MISALIGNED_FETCH,
            `EXCEPTION_FAULT_FETCH,
            `EXCEPTION_PAGE_FAULT_INST:     csr_mtval_r = exception_pc_i;
            `EXCEPTION_ILLEGAL_INSTRUCTION,
            `EXCEPTION_MISALIGNED_LOAD,
            `EXCEPTION_FAULT_LOAD,
            `EXCEPTION_MISALIGNED_STORE,
            `EXCEPTION_FAULT_STORE,
            `EXCEPTION_PAGE_FAULT_LOAD,
            `EXCEPTION_PAGE_FAULT_STORE:    csr_mtval_r = exception_addr_i;
            default:                        csr_mtval_r = 32'b0;
            endcase        
            // Fault cause
            csr_mcause_r = {28'b0, exception_i[3:0]};
        end
        else begin
            case(csr_waddr_i)
            // CSR - Machine
            `CSR_MSCRATCH: csr_mscratch_r = csr_wdata_i & `CSR_MSCRATCH_MASK;
            `CSR_MEPC:     csr_mepc_r     = csr_wdata_i & `CSR_MEPC_MASK;
            `CSR_MTVEC:    csr_mtvec_r    = csr_wdata_i & `CSR_MTVEC_MASK;
            `CSR_MCAUSE:   csr_mcause_r   = csr_wdata_i & `CSR_MCAUSE_MASK;
            `CSR_MTVAL:    csr_mtval_r    = csr_wdata_i & `CSR_MTVAL_MASK;
            `CSR_MSTATUS:  csr_sr_r       = csr_wdata_i & `CSR_MSTATUS_MASK;
            `CSR_MIP:      csr_mip_r      = csr_wdata_i & `CSR_MIP_MASK;
            `CSR_MIE:      csr_mie_r      = csr_wdata_i & `CSR_MIE_MASK;
            `CSR_MEDELEG:  csr_medeleg_r  = csr_wdata_i & `CSR_MEDELEG_MASK;
            `CSR_MIDELEG:  csr_mideleg_r  = csr_wdata_i & `CSR_MIDELEG_MASK;
            // Non-std behaviour
            `CSR_MTIMECMP: begin
                csr_mtimecmp_r = csr_wdata_i & `CSR_MTIMECMP_MASK;
                csr_mtime_ie_r = 1'b1;
            end
            default:
                ;
            endcase
        end
        // External interrupts
        // NOTE: If the machine level interrupts are delegated to supervisor, route the interrupts there instead..
        if (ext_intr_i   &&  csr_mideleg_q[`SR_IP_MEIP_R]) csr_mip_next_r[`SR_IP_SEIP_R] = 1'b1;
        if (ext_intr_i   && ~csr_mideleg_q[`SR_IP_MEIP_R]) csr_mip_next_r[`SR_IP_MEIP_R] = 1'b1;
        if (timer_intr_i &&  csr_mideleg_q[`SR_IP_MTIP_R]) csr_mip_next_r[`SR_IP_STIP_R] = 1'b1;
        if (timer_intr_i && ~csr_mideleg_q[`SR_IP_MTIP_R]) csr_mip_next_r[`SR_IP_MTIP_R] = 1'b1;

        // Optional: Internal timer compare interrupt
        if (SUPPORT_MTIMECMP && csr_mcycle_q == csr_mtimecmp_q)
        begin
            if (csr_mideleg_q[`SR_IP_MTIP_R])
                csr_mip_next_r[`SR_IP_STIP_R] = csr_mtime_ie_q;
            else
                csr_mip_next_r[`SR_IP_MTIP_R] = csr_mtime_ie_q;
            csr_mtime_ie_r  = 1'b0;
        end

        csr_mip_r = csr_mip_r | csr_mip_next_r;
    end

    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            // CSR - Machine
            csr_mepc_q         <= 32'b0;
            csr_sr_q           <= 32'b0;
            csr_mcause_q       <= 32'b0;
            csr_mtval_q        <= 32'b0;
            csr_mtvec_q        <= 32'b0;
            csr_mip_q          <= 32'b0;
            csr_mie_q          <= 32'b0;
            csr_mpriv_q        <= `PRIV_MACHINE;
            csr_mcycle_q       <= 32'b0;
            csr_mcycle_h_q     <= 32'b0;
            csr_mscratch_q     <= 32'b0;
            csr_mtimecmp_q     <= 32'b0;
            csr_mtime_ie_q     <= 1'b0;
            csr_medeleg_q      <= 32'b0;
            csr_mideleg_q      <= 32'b0;
            csr_mip_next_q     <= 32'b0;
        end
        else begin
            // CSR - Machine
            csr_mepc_q         <= csr_mepc_r;
            csr_sr_q           <= csr_sr_r;
            csr_mcause_q       <= csr_mcause_r;
            csr_mtval_q        <= csr_mtval_r;
            csr_mtvec_q        <= csr_mtvec_r;
            csr_mip_q          <= csr_mip_r;
            csr_mie_q          <= csr_mie_r;
            csr_mpriv_q        <= SUPPORT_SUPER ? csr_mpriv_r : `PRIV_MACHINE;
            csr_mcycle_q       <= csr_mcycle_r;
            csr_mscratch_q     <= csr_mscratch_r;
            csr_mtimecmp_q     <= SUPPORT_MTIMECMP ? csr_mtimecmp_r : 32'b0;
            csr_mtime_ie_q     <= SUPPORT_MTIMECMP ? csr_mtime_ie_r : 1'b0;
            csr_medeleg_q      <= SUPPORT_SUPER ? (csr_medeleg_r   & `CSR_MEDELEG_MASK) : 32'b0;
            csr_mideleg_q      <= SUPPORT_SUPER ? (csr_mideleg_r   & `CSR_MIDELEG_MASK) : 32'b0;
            csr_mip_next_q     <= buffer_mip_w ? csr_mip_next_r : 32'b0;
            // Increment upper cycle counter on lower 32-bit overflow
            if (csr_mcycle_q == 32'hFFFFFFFF)
                csr_mcycle_h_q <= csr_mcycle_h_q + 32'd1;
        end
    end

//-----------------------------------------------------------------
// CSR branch
//-----------------------------------------------------------------
    reg        branch_r;
    reg [31:0] branch_target_r;

    always @(*) begin
        branch_r        = 1'b0;
        branch_target_r = 32'b0;
        // Interrupts
        if(exception_i == `EXCEPTION_INTERRUPT) begin
            branch_r        = 1'b1;
            branch_target_r = csr_mtvec_q;
        end
        // Exception return
        else if(exception_i >= `EXCEPTION_ERET_U && exception_i <= `EXCEPTION_ERET_M) begin
            // MRET (return from machine)
            if(exception_i[1:0] == `PRIV_MACHINE) begin    
                branch_r        = 1'b1;
                branch_target_r = csr_mepc_q;
            end
        end
        // Exception - handled in machine mode
        else if(is_exception_w) begin
            branch_r        = 1'b1;
            branch_target_r = csr_mtvec_q;
        end
        // Fence / SATP register writes cause pipeline flushes
        else if (exception_i == `EXCEPTION_FENCE) begin
            branch_r        = 1'b1;
            branch_target_r = exception_pc_i + 32'd4;
        end
    end

    assign csr_branch_o = branch_r;
    assign csr_target_o = branch_target_r;

endmodule
