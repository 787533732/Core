module axi_if
(
    input   wire            clk_i           ,
    input   wire            rstn_i          ,
//axi
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
    input   wire            axi_rready_i    ,
//sram
    output  wire [31:0]     sram_addr_o     ,
    output  wire            sram_ren_o      ,
    input   wire [31:0]     sram_data_i 
);
    parameter IDLE = 0;
    parameter READ = 1;

    reg [2:0]  cnt_d;
    reg [2:0]  cnt_q;
    reg [1:0] state_q;
    reg [1:0] next_state_r;
    wire axi_rlast_d = (cnt_q == axi_arlen_i);
//next state generate 
    always @(*) begin
        case(state_q)
            IDLE : begin
                    if(axi_arvalid_i) 
                        next_state_r = READ;
                    else
                        next_state_r = IDLE;
            end
            READ : begin
                    if(axi_rready_i) begin
                        if(axi_rlast_d)
                            next_state_r = IDLE;
                        else    
                            next_state_r = READ;
                    end
            end
        endcase
    end


    reg [31:0] sram_addr_d;
    reg [31:0] sram_addr_q;
    reg        sram_ren_d;
    reg        sram_ren_q;
    reg        axi_arready_r;
    reg        axi_rvalid_d;
    reg        axi_rvalid_q;
    reg  axi_rlast_q;
    
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) 
            axi_rlast_q <= 1'b0;
        else 
            axi_rlast_q <= axi_rlast_d;
    end
//output
    always @(*) begin
        axi_arready_r = 1'b0;
        sram_addr_d   = 32'b0;
        sram_ren_d    = 1'b0;
        cnt_d         = 1'b0;
        case(state_q)
            IDLE : begin
                    if(axi_arvalid_i) begin
                        axi_arready_r = 1'b1;
                        sram_addr_d   = axi_araddr_i;
                        sram_ren_d    = 1'b1;
                    end
            end
            READ : begin
                    axi_arready_r = 1'b0;
                    if(axi_rready_i) begin
                        if(axi_rlast_d) begin
                            cnt_d        = 1'b0; 
                            sram_addr_d  = 32'd0;
                            sram_ren_d   = 1'b0;
                        end
                        else begin
                            cnt_d        = cnt_q + 1'b1;
                            sram_addr_d  = sram_addr_q + 4;
                            sram_ren_d   = 1'b1;
                        end
                    end 
            end
        endcase
    end
    always @(*) begin
        axi_rvalid_d = 1'b0;
        if((state_q == READ) && axi_rready_i) begin
            if(axi_rlast_q)
                axi_rvalid_d = 1'b0;
            else
                axi_rvalid_d = 1'b1;
        end
    end
//state update
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            state_q      <= IDLE;
            cnt_q        <= 3'd0;
            sram_addr_q  <= 32'd0;
            sram_ren_q   <= 1'b0;
            axi_rvalid_d <= 1'b0;
        end 
        else begin
            state_q      <= next_state_r;
            cnt_q        <= cnt_d;
            sram_addr_q  <= sram_addr_d;
            sram_ren_q   <= sram_ren_d;
            axi_rvalid_q <= axi_rvalid_d;
        end
    end
    
    assign axi_arready_o = axi_arready_r;
    assign axi_rdata_o   = sram_data_i;
    assign axi_rresp_o   = 2'b0;            //useless
    assign axi_rlast_o   = axi_rlast_q;
    assign axi_rvalid_o  = axi_rvalid_q;

    assign sram_addr_o   = sram_addr_q;
    assign sram_ren_o    = sram_ren_q;
endmodule