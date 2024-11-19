module axi2mem
(
    input   wire            clk_i           ,
    input   wire            rstn_i          ,
    //request
    input   wire [31:0]     axi_araddr_i    ,
    input   wire [ 7:0]     axi_arlen_i     ,
    input   wire            axi_arvalid_i   ,
    output  wire            axi_arready_o   ,
    //response
    output  wire [31:0]     axi_rdata_o     ,
    output  wire [ 1:0]     axi_rresp_o     ,
    output  wire            axi_rlast_o     ,//用于标记突发传输的最后一个cycle
    output  wire            axi_rvalid_o    ,      
    input   wire            axi_rready_i     
);

wire [31:0] sram_addr_w;
wire        sram_ren_w;
wire [31:0] sram_data_w;

axi_if axi_interface
(
    .clk_i              (clk_i          ),
    .rstn_i             (rstn_i         ),
//axi   
    //request   
    .axi_araddr_i       (axi_araddr_i   ),
    .axi_arlen_i        (axi_arlen_i    ),
    .axi_arvalid_i      (axi_arvalid_i  ),
    .axi_arready_o      (axi_arready_o  ),
    //response  
    .axi_rdata_o        (axi_rdata_o    ),
    .axi_rresp_o        (axi_rresp_o    ),
    .axi_rlast_o        (axi_rlast_o    ),//用于标记突发传输的最后一个cycle
    .axi_rvalid_o       (axi_rvalid_o   ),      
    .axi_rready_i       (axi_rready_i   ),
//sram  
    .sram_addr_o        (sram_addr_w    ),
    .sram_ren_o         (sram_ren_w     ),
    .sram_data_i        (sram_data_w    )
);

sram u_sram
(
    .clk_i              (clk_i          ),
    .addr_i             (sram_addr_w[16:2]),
    .ren_i              (sram_ren_w     ),

    .data_o             (sram_data_w    )
);

//-------------------------------------------------------------
// write: Write byte into memory
//-------------------------------------------------------------
task write; /*verilator public*/
    input [31:0] addr;
    input [7:0]  data;
begin
    case (addr[1:0])
    2'b00: u_sram.ram[addr/4][7:0]   = data;
    2'b01: u_sram.ram[addr/4][15:8]  = data;
    2'b10: u_sram.ram[addr/4][23:16] = data;
    2'b11: u_sram.ram[addr/4][31:24] = data;
    endcase
end
endtask

endmodule