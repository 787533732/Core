//read only
module sram
(
    input   wire                clk_i      ,
    input   wire [14:0]         addr_i     ,
    input   wire                ren_i      ,
    output  wire [31:0]         data_o
);

    reg [31:0] ram [1023:0];
    reg [31:0] ram_read_q;

    always @ (posedge clk_i) begin
        if(ren_i)
            ram_read_q <= ram[addr_i];
        else
            ram_read_q <= 32'b0;
    end

    assign data_o = ram_read_q;


endmodule
