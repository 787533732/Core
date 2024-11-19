`include "../core/define.v"
module lsu 
#(
    parameter MEM_CACHE_ADDR_MIN = 0 ,
    parameter MEM_CACHE_ADDR_MAX = 32'hffff_ffff
)
(
    input   wire                clk_i                   ,
    input   wire                rstn_i                  ,
    input   wire                opcode_valid_i          ,     
    input   wire [31:0]         opcode_opcode_i         ,
    input   wire [31:0]         opcode_ra_operand_i     ,
    input   wire [31:0]         opcode_rb_operand_i     ,
    //from mmu(D-Cache) (延迟两拍) 
    input   wire [31:0]         mem_data_rd_i           ,        
    input   wire                mem_accept_i            ,        
    input   wire                mem_ack_i               ,    
    input   wire                mem_error_i             ,    
    input   wire [10:0]         mem_resp_tag_i          ,        
    input   wire                mem_load_fault_i        ,            
    input   wire                mem_store_fault_i       , 
    //to mmu(D-Cache)（延迟一拍
    output  wire [31:0]         mem_addr_o              ,    
    output  wire [31:0]         mem_data_wr_o           ,        
    output  wire                mem_rd_o                ,    
    output  wire [ 3:0]         mem_wr_o                ,    
    output  wire                mem_cacheable_o         ,        
    output  wire [10:0]         mem_req_tag_o           ,        
    output  wire                mem_invalidate_o        ,            
    output  wire                mem_writeback_o         ,        
    output  wire                mem_flush_o             , 
    //to issue  
    output  wire                writeback_valid_o       ,
    output  wire [31:0]         writeback_value_o       ,
    output  wire [ 5:0]         writeback_exception_o   ,
    output  wire                stall_o             
);

    wire load_inst_w = (((opcode_opcode_i & `INST_LB_MASK ) == `INST_LB)  || 
                        ((opcode_opcode_i & `INST_LH_MASK ) == `INST_LH)  || 
                        ((opcode_opcode_i & `INST_LW_MASK ) == `INST_LW)  || 
                        ((opcode_opcode_i & `INST_LBU_MASK) == `INST_LBU) || 
                        ((opcode_opcode_i & `INST_LHU_MASK) == `INST_LHU) || 
                        ((opcode_opcode_i & `INST_LWU_MASK) == `INST_LWU));

    wire load_signed_inst_w = (((opcode_opcode_i & `INST_LB_MASK) == `INST_LB)  || 
                               ((opcode_opcode_i & `INST_LH_MASK) == `INST_LH)  || 
                               ((opcode_opcode_i & `INST_LW_MASK) == `INST_LW));

    wire store_inst_w = (((opcode_opcode_i & `INST_SB_MASK) == `INST_SB)  || 
                         ((opcode_opcode_i & `INST_SH_MASK) == `INST_SH)  || 
                         ((opcode_opcode_i & `INST_SW_MASK) == `INST_SW));

    wire req_lb_w = ((opcode_opcode_i & `INST_LB_MASK) == `INST_LB) || ((opcode_opcode_i & `INST_LBU_MASK) == `INST_LBU);
    wire req_lh_w = ((opcode_opcode_i & `INST_LH_MASK) == `INST_LH) || ((opcode_opcode_i & `INST_LHU_MASK) == `INST_LHU);
    wire req_lw_w = ((opcode_opcode_i & `INST_LW_MASK) == `INST_LW) || ((opcode_opcode_i & `INST_LWU_MASK) == `INST_LWU);
    wire req_sb_w = ((opcode_opcode_i & `INST_LB_MASK) == `INST_SB);
    wire req_sh_w = ((opcode_opcode_i & `INST_LH_MASK) == `INST_SH);
    wire req_sw_w = ((opcode_opcode_i & `INST_LW_MASK) == `INST_SW);

    wire req_sw_lw_w = ((opcode_opcode_i & `INST_SW_MASK) == `INST_SW) || ((opcode_opcode_i & `INST_LW_MASK) == `INST_LW) || ((opcode_opcode_i & `INST_LWU_MASK) == `INST_LWU);
    wire req_sh_lh_w = ((opcode_opcode_i & `INST_SH_MASK) == `INST_SH) || ((opcode_opcode_i & `INST_LH_MASK) == `INST_LH) || ((opcode_opcode_i & `INST_LHU_MASK) == `INST_LHU);

    reg [ 31:0]  mem_addr_q;
    reg          mem_unaligned_e1_q;
    reg          mem_unaligned_e2_q;
    reg [ 31:0]  mem_data_wr_q;
    reg          mem_rd_q;
    reg [  3:0]  mem_wr_q;
    reg          mem_cacheable_q;
    reg          mem_invalidate_q;
    reg          mem_writeback_q;
    reg          mem_flush_q;
    reg          mem_load_q;
    reg          mem_xb_q;
    reg          mem_xh_q;
    reg          mem_ls_q;

    reg pending_lsu_e2_q;//等待信号
    //指令需要访存时，信号拉高
    wire issue_lsu_e1_w    = (mem_rd_o || (|mem_wr_o) || mem_writeback_o || mem_invalidate_o || mem_flush_o) && mem_accept_i;
    //产生e2阶段的参考信号
    wire complete_ok_e2_w  = mem_ack_i & ~mem_error_i;
    wire complete_err_e2_w = mem_ack_i & mem_error_i;

    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            pending_lsu_e2_q <= 1'b0;
        else if(issue_lsu_e1_w)
            pending_lsu_e2_q <= 1'b1;
        else if(complete_ok_e2_w || complete_err_e2_w)
            pending_lsu_e2_q <= 1'b0;
    end 
    //如果D-Cache还没准备好，延迟后面指令
    wire delay_lsu_e2_w = pending_lsu_e2_q && !complete_ok_e2_w;
    
    always @ (posedge clk_i or negedge rstn_i) begin
        if (!rstn_i)
            mem_unaligned_e2_q <= 1'b0;
        else
            mem_unaligned_e2_q <= mem_unaligned_e1_q & ~delay_lsu_e2_w;
    end

    reg [31:0]  mem_addr_r;
    reg         mem_unaligned_r;
    reg [31:0]  mem_data_r;
    reg         mem_rd_r;
    reg [3:0]   mem_wr_r;
    always @(*) begin
        mem_addr_r      = 32'b0;
        mem_unaligned_r = 1'b0;
        mem_data_r      = 32'b0;
        mem_rd_r        = 1'b1;
        mem_wr_r        = 4'b0;
        //计算访问地址
        if(opcode_valid_i && ((opcode_opcode_i & `INST_CSRRW_MASK) == `INST_CSRRW))
            mem_addr_r = opcode_ra_operand_i;
        else if(opcode_valid_i && load_inst_w)
            mem_addr_r = opcode_ra_operand_i + {{20{opcode_opcode_i[31]}}, opcode_opcode_i[31:20]};
        else 
            mem_addr_r = opcode_ra_operand_i + {{20{opcode_opcode_i[31]}}, opcode_opcode_i[31:25], opcode_opcode_i[11:7]};
        //判断对齐情况
        if(opcode_valid_i && req_sw_lw_w)
            mem_unaligned_r = (mem_addr_r[1:0] != 2'b0);
        else if(opcode_valid_i && req_sh_lh_w)
            mem_unaligned_r = (mem_addr_r[0]);
        //判断需不需要rd
        mem_rd_r = (opcode_valid_i && load_inst_w && !mem_unaligned_r);//只有Load指令需要rd
        //根据Store指令设置确定数据和写使能
        if(opcode_valid_i && ((opcode_opcode_i & `INST_SW_MASK) == `INST_SW) && !mem_unaligned_r) begin
            mem_data_r = opcode_rb_operand_i;
            mem_wr_r   = 4'hf;
        end
        else if(opcode_valid_i && ((opcode_opcode_i & `INST_SH_MASK) == `INST_SH) && !mem_unaligned_r) begin
            case(mem_addr_r[1:0])
            2'h0: begin
                mem_data_r = {16'h0000, opcode_rb_operand_i[15:0]};
                mem_wr_r   = 4'b0011;
            end
            2'h2: begin
                mem_data_r = {opcode_rb_operand_i[15:0], 16'h0000};
                mem_wr_r   = 4'b1100;  
            end
            default: begin
                mem_data_r = 32'b0;
                mem_wr_r   = 4'b0;  
            end
            endcase
        end
        else if(opcode_valid_i && ((opcode_opcode_i & `INST_SB_MASK) == `INST_SB)) begin
            case(mem_addr_r[1:0])
            2'h0: begin
                mem_data_r = {24'h00_0000, opcode_rb_operand_i[7:0]};
                mem_wr_r   = 4'b0001;
            end
            2'h1: begin
                mem_data_r = {16'h0000, opcode_rb_operand_i[7:0], 8'h00};
                mem_wr_r   = 4'b0010;  
            end
            2'h2: begin
                mem_data_r = {8'h00, opcode_rb_operand_i[7:0], 16'h0000};
                mem_wr_r   = 4'b0100;  
            end
            2'h3: begin
                mem_data_r = {opcode_rb_operand_i[7:0], 24'h00_0000};
                mem_wr_r   = 4'b1000;  
            end
            default: begin
                mem_data_r = 32'b0;
                mem_wr_r   = 4'b0;  
            end
            endcase
        end
        else    
            mem_wr_r = 4'b0;   
    end
    //异常？
    wire dcache_flush_w      = ((opcode_opcode_i & `INST_CSRRW_MASK) == `INST_CSRRW) && (opcode_opcode_i[31:20] == `CSR_DFLUSH);
    wire dcache_writeback_w  = ((opcode_opcode_i & `INST_CSRRW_MASK) == `INST_CSRRW) && (opcode_opcode_i[31:20] == `CSR_DWRITEBACK);
    wire dcache_invalidate_w = ((opcode_opcode_i & `INST_CSRRW_MASK) == `INST_CSRRW) && (opcode_opcode_i[31:20] == `CSR_DINVALIDATE);




    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            mem_addr_q         <= 32'b0;
            mem_unaligned_e1_q <=  1'b0;
            mem_data_wr_q      <= 32'b0;
            mem_rd_q           <=  1'b0;
            mem_wr_q           <=  1'b0;
            mem_cacheable_q    <=  1'b0;
            mem_invalidate_q   <=  1'b0;
            mem_writeback_q    <=  1'b0;
            mem_flush_q        <=  1'b0;
            mem_load_q         <=  1'b0;
            mem_xb_q           <=  1'b0;
            mem_xh_q           <=  1'b0;
            mem_ls_q           <=  1'b0;
        end
        //D-Cache访问错误
        else if(complete_err_e2_w || mem_unaligned_e2_q) begin
            mem_addr_q         <= 32'b0;
            mem_unaligned_e1_q <=  1'b0;
            mem_data_wr_q      <= 32'b0;
            mem_rd_q           <=  1'b0;
            mem_wr_q           <=  1'b0;
            mem_cacheable_q    <=  1'b0;
            mem_invalidate_q   <=  1'b0;
            mem_writeback_q    <=  1'b0;
            mem_flush_q        <=  1'b0;
            mem_load_q         <=  1'b0;
            mem_xb_q           <=  1'b0;
            mem_xh_q           <=  1'b0;
            mem_ls_q           <=  1'b0;    
        end
        //延迟状态下,保持不变
        else if ((mem_rd_q || (|mem_wr_q) || mem_unaligned_e1_q) && delay_lsu_e2_w) begin
            mem_addr_q         <= mem_addr_q;        
            mem_unaligned_e1_q <= mem_unaligned_e1_q;
            mem_data_wr_q      <= mem_data_wr_q;     
            mem_rd_q           <= mem_rd_q;          
            mem_wr_q           <= mem_wr_q;          
            mem_cacheable_q    <= mem_cacheable_q;   
            mem_invalidate_q   <= mem_invalidate_q;  
            mem_writeback_q    <= mem_writeback_q;   
            mem_flush_q        <= mem_flush_q;       
            mem_load_q         <= mem_load_q;        
            mem_xb_q           <= mem_xb_q;          
            mem_xh_q           <= mem_xh_q;          
            mem_ls_q           <= mem_ls_q;          
        end
    else if (!((mem_writeback_o || mem_invalidate_o || mem_flush_o || mem_rd_o || mem_wr_o != 4'b0) && !mem_accept_i)) begin
        mem_addr_q         <= 32'b0;
        mem_data_wr_q      <= mem_data_r;
        mem_rd_q           <= mem_rd_r;
        mem_wr_q           <= mem_wr_r;
        mem_cacheable_q    <= 1'b0;
        mem_invalidate_q   <= 1'b0;
        mem_writeback_q    <= 1'b0;
        mem_flush_q        <= 1'b0;
        mem_unaligned_e1_q <= mem_unaligned_r;
        mem_load_q         <= opcode_valid_i && load_inst_w;
        mem_xb_q           <= req_lb_w | req_sb_w;
        mem_xh_q           <= req_lh_w | req_sh_w;
        mem_ls_q           <= load_signed_inst_w;
    /* verilator lint_off UNSIGNED */
    /* verilator lint_off CMPCONST */
        mem_cacheable_q  <= (mem_addr_r >= MEM_CACHE_ADDR_MIN && mem_addr_r <= MEM_CACHE_ADDR_MAX) ||
                            (opcode_valid_i && (dcache_invalidate_w || dcache_writeback_w || dcache_flush_w));
    /* verilator lint_on CMPCONST */
    /* verilator lint_on UNSIGNED */

        mem_invalidate_q <= opcode_valid_i & dcache_invalidate_w;
        mem_writeback_q  <= opcode_valid_i & dcache_writeback_w;
        mem_flush_q      <= opcode_valid_i & dcache_flush_w;
        mem_addr_q       <= mem_addr_r;
    end
end

    assign mem_addr_o       = {mem_addr_q[31:2], 2'b0};
    assign mem_data_wr_o    = mem_data_wr_q;
    assign mem_rd_o         = mem_rd_q & ~delay_lsu_e2_w;
    assign mem_wr_o         = mem_wr_q & ~{4{delay_lsu_e2_w}};
    assign mem_cacheable_o  = mem_cacheable_q;
    assign mem_req_tag_o    = 11'b0;
    assign mem_invalidate_o = mem_invalidate_q;
    assign mem_writeback_o  = mem_writeback_q;
    assign mem_flush_o      = mem_flush_q;

    assign stall_o          = ((mem_writeback_o || mem_invalidate_o || mem_flush_o || mem_rd_o || mem_wr_o != 4'b0) && !mem_accept_i) || delay_lsu_e2_w || mem_unaligned_e1_q;

    
    wire [31:0] resp_addr_w;
    wire        resp_signed_w;
    wire        resp_byte_w;
    wire        resp_half_w;
    wire        resp_load_w;
    
    lsu_fifo
    #(
        .WIDTH (36),
        .DEPTH (2),
        .ADDR_W(1)
    )
    u1_fifo
    (
        .clk_i           (clk_i),
        .rstn_i          (rstn_i),
        .data_in_vld_i   (((mem_rd_o || (|mem_wr_o) || mem_writeback_o || mem_invalidate_o || mem_flush_o) && mem_accept_i) || (mem_unaligned_e1_q && ~delay_lsu_e2_w)),//发生读写或者异常
        .data_in_rdy_o   (),
        .data_in_i       ({mem_addr_q, mem_ls_q, mem_xh_q, mem_xb_q, mem_load_q}),   

        .data_out_vld_o  (),   
        .data_out_rdy_i  (mem_ack_i || mem_unaligned_e2_q),
        .data_out_o      ({resp_addr_w, resp_signed_w, resp_half_w, resp_byte_w, resp_load_w}) 
    );

    reg [31:0] wb_result_r;
    reg [ 1:0] addr_lsb_r;
    reg        load_byte_r;
    reg        load_half_r;
    reg        load_signed_r;
    
//Load inst
    always @(*) begin
        wb_result_r   = 32'b0; 
        addr_lsb_r    = resp_addr_w[1:0];
        load_byte_r   = resp_byte_w;
        load_half_r   = resp_half_w;
        load_signed_r = resp_signed_w;
        //访问产生错误
        if((mem_ack_i && mem_error_i) || mem_unaligned_e2_q)
            wb_result_r = resp_addr_w;//返回错误地址
        else if(mem_ack_i && resp_load_w) begin
            if(load_byte_r) begin
                case (addr_lsb_r[1:0])
                    2'h0: wb_result_r = {24'b0, mem_data_rd_i[7:0]};
                    2'h1: wb_result_r = {24'b0, mem_data_rd_i[15:8]};
                    2'h2: wb_result_r = {24'b0, mem_data_rd_i[23:16]};
                    2'h3: wb_result_r = {24'b0, mem_data_rd_i[31:24]};
                endcase
                if(load_signed_r && wb_result_r[7])//加载有符号数时更新result
                        wb_result_r = {24'hff_ffff, wb_result_r[7:0]};
            end
            else if(load_half_r) begin
                if(!addr_lsb_r[1])
                    wb_result_r = {16'b0, mem_data_rd_i[15:0]};
                else if(addr_lsb_r[1])
                    wb_result_r = {16'b0, mem_data_rd_i[31:16]};
                if(load_signed_r && wb_result_r[15])//加载有符号数时更新result
                    wb_result_r = {16'hffff, wb_result_r[15:0]};
            end
            else
                wb_result_r = mem_data_rd_i;
        end
    end

    assign writeback_valid_o  = mem_ack_i | mem_unaligned_e2_q;
    assign writeback_value_o  = wb_result_r;

    wire fault_load_align_w   = mem_unaligned_e2_q && resp_load_w;
    wire fault_store_align_w  = mem_unaligned_e2_q && ~resp_load_w;
    wire fault_load_page_w    = mem_error_i && resp_load_w;
    wire fault_store_page_w   = mem_error_i && ~resp_load_w;
    wire fault_load_bus_w     = mem_error_i && mem_load_fault_i;
    wire fault_store_bus_w    = mem_error_i && mem_store_fault_i;

    assign writeback_exception_o     = fault_load_align_w  ? `EXCEPTION_MISALIGNED_LOAD:
                                       fault_store_align_w ? `EXCEPTION_MISALIGNED_STORE:
                                       fault_load_page_w   ? `EXCEPTION_PAGE_FAULT_LOAD:
                                       fault_store_page_w  ? `EXCEPTION_PAGE_FAULT_STORE:
                                       fault_load_bus_w    ? `EXCEPTION_FAULT_LOAD:
                                       fault_store_bus_w   ? `EXCEPTION_FAULT_STORE:
                                       `EXCEPTION_W'b0;

endmodule

    
module lsu_fifo
#(
    parameter WIDTH    = 8,
    parameter DEPTH    = 4,
    parameter ADDR_W   = 2
)
(
    input   wire                    clk_i           ,
    input   wire                    rstn_i           ,
    input   wire                    data_in_vld_i   ,
    output  wire                    data_in_rdy_o   ,
    input   wire [WIDTH-1:0]        data_in_i       ,

    output  wire                    data_out_vld_o  ,   
    input   wire                    data_out_rdy_i  ,
    output  wire [WIDTH-1:0]        data_out_o       
);

    localparam COUNT_W = ADDR_W + 1;

    reg [WIDTH-1:0]   ram_q[DEPTH-1:0];
    reg [ADDR_W-1:0]  rd_ptr_q;
    reg [ADDR_W-1:0]  wr_ptr_q;
    reg [COUNT_W-1:0] count_q;

    wire wr_en = data_in_vld_i && data_in_rdy_o;
    wire rd_en = data_out_vld_o && data_out_rdy_i;
    integer i;
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            rd_ptr_q <= {(ADDR_W){1'b0}};
            wr_ptr_q <= {(ADDR_W){1'b0}};
            count_q  <= {(COUNT_W){1'b0}};
            for(i = 0; i < DEPTH; i = i + 1) begin
                ram_q[i] <= {(WIDTH){1'b0}};
            end
        end
        else begin
            if(wr_en) begin
                ram_q[wr_ptr_q] <= data_in_i;
                wr_ptr_q        <= wr_ptr_q + 1;
            end
            if(rd_en)
                rd_ptr_q <= rd_ptr_q + 1;
            if(wr_en && ~rd_en)
                count_q  <= count_q + 1;
            else if(~wr_en && rd_en)
                count_q  <= count_q - 1;  
        end 
    end

    assign data_in_rdy_o  = (count_q != DEPTH);
    assign data_out_vld_o = (count_q != 0);
    assign data_out_o     = ram_q[rd_ptr_q];

endmodule