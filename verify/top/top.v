module top
(
    input   wire             clk_i             ,
    input   wire             rstn_i             
);

wire          mem_i_rd_w;
wire          mem_i_flush_w;
wire          mem_i_invalidate_w;
wire [ 31:0]  mem_i_pc_w;
wire [ 31:0]  mem_d_addr_w;
wire [ 31:0]  mem_d_data_wr_w;
wire          mem_d_rd_w;
wire [  3:0]  mem_d_wr_w;
wire          mem_d_cacheable_w;
wire [ 10:0]  mem_d_req_tag_w;
wire          mem_d_invalidate_w;
wire          mem_d_writeback_w;
wire          mem_d_flush_w;
wire          mem_i_accept_w;
wire          mem_i_valid_w;
wire          mem_i_error_w;
wire [ 63:0]  mem_i_inst_w;
wire [ 31:0]  mem_d_data_rd_w;
wire          mem_d_accept_w;
wire          mem_d_ack_w;
wire          mem_d_error_w;
wire [ 10:0]  mem_d_resp_tag_w;
wire [ 31:0]  axi_araddr_w;   
wire [ 7:0]   axi_arlen_w;    
wire          axi_arvalid_w;  
wire          axi_arready_w;  
wire [ 31:0]  axi_rdata_w;    
wire [ 1:0]   axi_rresp_w;    
wire          axi_rlast_w;    
wire          axi_rvalid_w;   
wire          axi_rready_w;   

core u_core
(
    .clk_i                  (clk_i              ),
    .rstn_i                 (rstn_i             ),
    .mem_d_data_rd_i        (mem_d_data_rd_w    ),
    .mem_d_accept_i         (mem_d_accept_w     ),
    .mem_d_ack_i            (mem_d_ack_w        ),
    .mem_d_error_i          (mem_d_error_w      ),
    .mem_d_resp_tag_i       (mem_d_resp_tag_w   ),
    .mem_i_accept_i         (mem_i_accept_w     ),
    .mem_i_valid_i          (mem_i_valid_w      ),
    .mem_i_error_i          (mem_i_error_w      ),
    .mem_i_inst_i           (mem_i_inst_w       ),
    .intr_i                 (1'b0               ),
    .reset_vector_i         (32'h80000000       ),
    .cpu_id_i               ('b0                ),

    // Outputs
    .mem_d_addr_o           (mem_d_addr_w       ),
    .mem_d_data_wr_o        (mem_d_data_wr_w    ),
    .mem_d_rd_o             (mem_d_rd_w         ),
    .mem_d_wr_o             (mem_d_wr_w         ),
    .mem_d_cacheable_o      (mem_d_cacheable_w  ),
    .mem_d_req_tag_o        (mem_d_req_tag_w    ),
    .mem_d_invalidate_o     (mem_d_invalidate_w ),
    .mem_d_writeback_o      (mem_d_writeback_w  ),
    .mem_d_flush_o          (mem_d_flush_w      ),
    .mem_i_rd_o             (mem_i_rd_w         ),
    .mem_i_flush_o          (mem_i_flush_w      ),
    .mem_i_invalidate_o     (mem_i_invalidate_w ),
    .mem_i_pc_o             (mem_i_pc_w         )

);

tcm_mem u_ram
(
    // Inputs
    .clk_i                  (clk_i              ),
    .rstn_i                 (rstn_i             ),
    .mem_i_rd_i             (                   ),
    .mem_i_flush_i          (                   ),
    .mem_i_invalidate_i     (                   ),
    .mem_i_pc_i             (                   ),
    .mem_d_addr_i           (mem_d_addr_w       ),
    .mem_d_data_wr_i        (mem_d_data_wr_w    ),
    .mem_d_rd_i             (mem_d_rd_w         ),
    .mem_d_wr_i             (mem_d_wr_w         ),
    .mem_d_cacheable_i      (mem_d_cacheable_w  ),
    .mem_d_req_tag_i        (mem_d_req_tag_w    ),
    .mem_d_invalidate_i     (mem_d_invalidate_w ),
    .mem_d_writeback_i      (mem_d_writeback_w  ),
    .mem_d_flush_i          (mem_d_flush_w      ),

    // Outputs
    .mem_i_accept_o         (                   ),
    .mem_i_valid_o          (                   ),
    .mem_i_error_o          (                   ),
    .mem_i_inst_o           (                   ),
    .mem_d_data_rd_o        (mem_d_data_rd_w    ),
    .mem_d_accept_o         (mem_d_accept_w     ),
    .mem_d_ack_o            (mem_d_ack_w        ),
    .mem_d_error_o          (mem_d_error_w      ),
    .mem_d_resp_tag_o       (mem_d_resp_tag_w   )
);

icache
#(
     .AXI_ID           (0)
)u_icache
(
    .clk_i                  (clk_i              ),
    .rstn_i                 (rstn_i             ),

    .req_rd_i               (mem_i_rd_w         ),
    .req_flush_i            (mem_i_flush_w      ),
    .req_invalidate_i       (mem_i_invalidate_w ),
    .req_pc_i               (mem_i_pc_w         ),
    .req_accept_o           (mem_i_accept_w     ),
    .req_valid_o            (mem_i_valid_w      ),
    .req_error_o            (mem_i_error_w      ),
    .req_inst_o             (mem_i_inst_w       ),
//axi interface
    //read address channel
    .axi_arvalid_o     (axi_arvalid_w),
    .axi_araddr_o      (axi_araddr_w),
    .axi_arid_o        (),
    .axi_arlen_o       (axi_arlen_w),
    .axi_arburst_o     (),
    .axi_arready_i     (axi_arready_w),
    //read data channel  
    .axi_rdata_i       (axi_rdata_w),
    .axi_rresp_i       (axi_rresp_w),
    .axi_rid_i         (),
    .axi_rlast_i       (axi_rlast_w),//用于标记突发传输的最后一个cycle
    .axi_rvalid_i      (axi_rvalid_w),      
    .axi_rready_o      (axi_rready_w)
);

axi2mem u_rom
(
    .clk_i              (clk_i          ),
    .rstn_i             (rstn_i         ),
    //request
    .axi_araddr_i       (axi_araddr_w   ),
    .axi_arlen_i        (axi_arlen_w    ),
    .axi_arvalid_i      (axi_arvalid_w  ),
    .axi_arready_o      (axi_arready_w  ),
    //response
    .axi_rdata_o        (axi_rdata_w    ),
    .axi_rresp_o        (axi_rresp_w    ),
    .axi_rlast_o        (axi_rlast_w    ),//用于标记突发传输的最后一个cycle
    .axi_rvalid_o       (axi_rvalid_w   ),      
    .axi_rready_i       (axi_rready_w   ) 
);

endmodule