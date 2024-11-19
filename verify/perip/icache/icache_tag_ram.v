module icache_tag_ram
(
    input   wire          clk_i     ,
    input   wire [ 7:0]   addr_i    ,
    input   wire [19:0]   data_i    ,
    input   wire          wr_i      ,
 
    output  wire [19:0]   data_o
);

    reg [19:0] ram [255:0];
    reg [19:0] ram_read_q;

    always @ (posedge clk_i) begin
        if (wr_i) begin
            ram[addr_i] <= data_i;
        end
        ram_read_q <= ram[addr_i];
    end

    assign data_o = ram_read_q;

endmodule
