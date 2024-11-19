module regfile (
    input   wire                clk_i       ,
    input   wire                rstn_i      ,
    //two write port
    input   wire [ 4:0]         rd0_i       ,
    input   wire [31:0]         rd0_value_i ,
    input   wire [ 4:0]         rd1_i       ,    
    input   wire [31:0]         rd1_value_i ,
    //four read port
    input   wire [ 4:0]         ra0_i       ,
    input   wire [ 4:0]         rb0_i       ,
    output  wire [31:0]         ra0_value_o ,
    output  wire [31:0]         rb0_value_o ,
    
    input   wire [ 4:0]         ra1_i       ,
    input   wire [ 4:0]         rb1_i       ,
    output  wire [31:0]         ra1_value_o ,
    output  wire [31:0]         rb1_value_o
);
    reg [31:0] reg_r1_q;
    reg [31:0] reg_r2_q;
    reg [31:0] reg_r3_q;
    reg [31:0] reg_r4_q;
    reg [31:0] reg_r5_q;
    reg [31:0] reg_r6_q;
    reg [31:0] reg_r7_q;
    reg [31:0] reg_r8_q;
    reg [31:0] reg_r9_q;
    reg [31:0] reg_r10_q;
    reg [31:0] reg_r11_q;
    reg [31:0] reg_r12_q;
    reg [31:0] reg_r13_q;
    reg [31:0] reg_r14_q;
    reg [31:0] reg_r15_q;
    reg [31:0] reg_r16_q;
    reg [31:0] reg_r17_q;
    reg [31:0] reg_r18_q;
    reg [31:0] reg_r19_q;
    reg [31:0] reg_r20_q;
    reg [31:0] reg_r21_q;
    reg [31:0] reg_r22_q;
    reg [31:0] reg_r23_q;
    reg [31:0] reg_r24_q;
    reg [31:0] reg_r25_q;
    reg [31:0] reg_r26_q;
    reg [31:0] reg_r27_q;
    reg [31:0] reg_r28_q;
    reg [31:0] reg_r29_q;
    reg [31:0] reg_r30_q;
    reg [31:0] reg_r31_q;

    // Simulation friendly names
    wire [31:0] x0_zero_w = 32'b0;
    wire [31:0] x1_ra_w   = reg_r1_q;
    wire [31:0] x2_sp_w   = reg_r2_q;
    wire [31:0] x3_gp_w   = reg_r3_q;
    wire [31:0] x4_tp_w   = reg_r4_q;
    wire [31:0] x5_t0_w   = reg_r5_q;
    wire [31:0] x6_t1_w   = reg_r6_q;
    wire [31:0] x7_t2_w   = reg_r7_q;
    wire [31:0] x8_s0_w   = reg_r8_q;
    wire [31:0] x9_s1_w   = reg_r9_q;
    wire [31:0] x10_a0_w  = reg_r10_q;
    wire [31:0] x11_a1_w  = reg_r11_q;
    wire [31:0] x12_a2_w  = reg_r12_q;
    wire [31:0] x13_a3_w  = reg_r13_q;
    wire [31:0] x14_a4_w  = reg_r14_q;
    wire [31:0] x15_a5_w  = reg_r15_q;
    wire [31:0] x16_a6_w  = reg_r16_q;
    wire [31:0] x17_a7_w  = reg_r17_q;
    wire [31:0] x18_s2_w  = reg_r18_q;
    wire [31:0] x19_s3_w  = reg_r19_q;
    wire [31:0] x20_s4_w  = reg_r20_q;
    wire [31:0] x21_s5_w  = reg_r21_q;
    wire [31:0] x22_s6_w  = reg_r22_q;
    wire [31:0] x23_s7_w  = reg_r23_q;
    wire [31:0] x24_s8_w  = reg_r24_q;
    wire [31:0] x25_s9_w  = reg_r25_q;
    wire [31:0] x26_s10_w = reg_r26_q;
    wire [31:0] x27_s11_w = reg_r27_q;
    wire [31:0] x28_t3_w  = reg_r28_q;
    wire [31:0] x29_t4_w  = reg_r29_q;
    wire [31:0] x30_t5_w  = reg_r30_q;
    wire [31:0] x31_t6_w  = reg_r31_q;

    always @(posedge clk_i) begin
        if(!rstn_i) begin
            reg_r1_q  <= 32'h11;
            reg_r2_q  <= 32'h11;
            reg_r3_q  <= 32'h0;
            reg_r4_q  <= 32'h0;
            reg_r5_q  <= 32'h0;
            reg_r6_q  <= 32'h0;
            reg_r7_q  <= 32'h0;
            reg_r8_q  <= 32'h0;
            reg_r9_q  <= 32'h0;
            reg_r10_q <= 32'h0; 
            reg_r11_q <= 32'h0; 
            reg_r12_q <= 32'h0; 
            reg_r13_q <= 32'h0; 
            reg_r14_q <= 32'h0; 
            reg_r15_q <= 32'h0; 
            reg_r16_q <= 32'h0; 
            reg_r17_q <= 32'h0; 
            reg_r18_q <= 32'h0; 
            reg_r19_q <= 32'h0; 
            reg_r20_q <= 32'h0; 
            reg_r21_q <= 32'h0; 
            reg_r22_q <= 32'h0; 
            reg_r23_q <= 32'h0; 
            reg_r24_q <= 32'h0; 
            reg_r25_q <= 32'h0; 
            reg_r26_q <= 32'h0; 
            reg_r27_q <= 32'h0; 
            reg_r28_q <= 32'h0; 
            reg_r29_q <= 32'h0; 
            reg_r30_q <= 32'h0; 
            reg_r31_q <= 32'h0; 
        end
        else begin 
            if      (rd0_i == 5'd1 ) reg_r1_q  <= rd0_value_i;
            else if (rd1_i == 5'd1 ) reg_r1_q  <= rd1_value_i;
            if      (rd0_i == 5'd2 ) reg_r2_q  <= rd0_value_i;
            else if (rd1_i == 5'd2 ) reg_r2_q  <= rd1_value_i;
            if      (rd0_i == 5'd3 ) reg_r3_q  <= rd0_value_i;
            else if (rd1_i == 5'd3 ) reg_r3_q  <= rd1_value_i;
            if      (rd0_i == 5'd4 ) reg_r4_q  <= rd0_value_i;
            else if (rd1_i == 5'd4 ) reg_r4_q  <= rd1_value_i;
            if      (rd0_i == 5'd5 ) reg_r5_q  <= rd0_value_i;
            else if (rd1_i == 5'd5 ) reg_r5_q  <= rd1_value_i;
            if      (rd0_i == 5'd6 ) reg_r6_q  <= rd0_value_i;
            else if (rd1_i == 5'd6 ) reg_r6_q  <= rd1_value_i;
            if      (rd0_i == 5'd7 ) reg_r7_q  <= rd0_value_i;
            else if (rd1_i == 5'd7 ) reg_r7_q  <= rd1_value_i;
            if      (rd0_i == 5'd8 ) reg_r8_q  <= rd0_value_i;
            else if (rd1_i == 5'd8 ) reg_r8_q  <= rd1_value_i;
            if      (rd0_i == 5'd9 ) reg_r9_q  <= rd0_value_i;
            else if (rd1_i == 5'd9 ) reg_r9_q  <= rd1_value_i;
            if      (rd0_i == 5'd10) reg_r10_q <= rd0_value_i;
            else if (rd1_i == 5'd10) reg_r10_q <= rd1_value_i;
            if      (rd0_i == 5'd11) reg_r11_q <= rd0_value_i;
            else if (rd1_i == 5'd11) reg_r11_q <= rd1_value_i;
            if      (rd0_i == 5'd12) reg_r12_q <= rd0_value_i;
            else if (rd1_i == 5'd12) reg_r12_q <= rd1_value_i;
            if      (rd0_i == 5'd13) reg_r13_q <= rd0_value_i;
            else if (rd1_i == 5'd13) reg_r13_q <= rd1_value_i;
            if      (rd0_i == 5'd14) reg_r14_q <= rd0_value_i;
            else if (rd1_i == 5'd14) reg_r14_q <= rd1_value_i;
            if      (rd0_i == 5'd15) reg_r15_q <= rd0_value_i;
            else if (rd1_i == 5'd15) reg_r15_q <= rd1_value_i;
            if      (rd0_i == 5'd16) reg_r16_q <= rd0_value_i;
            else if (rd1_i == 5'd16) reg_r16_q <= rd1_value_i;
            if      (rd0_i == 5'd17) reg_r17_q <= rd0_value_i;
            else if (rd1_i == 5'd17) reg_r17_q <= rd1_value_i;
            if      (rd0_i == 5'd18) reg_r18_q <= rd0_value_i;
            else if (rd1_i == 5'd18) reg_r18_q <= rd1_value_i;
            if      (rd0_i == 5'd19) reg_r19_q <= rd0_value_i;
            else if (rd1_i == 5'd19) reg_r19_q <= rd1_value_i;
            if      (rd0_i == 5'd20) reg_r20_q <= rd0_value_i;
            else if (rd1_i == 5'd20) reg_r20_q <= rd1_value_i;
            if      (rd0_i == 5'd21) reg_r21_q <= rd0_value_i;
            else if (rd1_i == 5'd21) reg_r21_q <= rd1_value_i;
            if      (rd0_i == 5'd22) reg_r22_q <= rd0_value_i;
            else if (rd1_i == 5'd22) reg_r22_q <= rd1_value_i;
            if      (rd0_i == 5'd23) reg_r23_q <= rd0_value_i;
            else if (rd1_i == 5'd23) reg_r23_q <= rd1_value_i;
            if      (rd0_i == 5'd24) reg_r24_q <= rd0_value_i;
            else if (rd1_i == 5'd24) reg_r24_q <= rd1_value_i;
            if      (rd0_i == 5'd25) reg_r25_q <= rd0_value_i;
            else if (rd1_i == 5'd25) reg_r25_q <= rd1_value_i;
            if      (rd0_i == 5'd26) reg_r26_q <= rd0_value_i;
            else if (rd1_i == 5'd26) reg_r26_q <= rd1_value_i;
            if      (rd0_i == 5'd27) reg_r27_q <= rd0_value_i;
            else if (rd1_i == 5'd27) reg_r27_q <= rd1_value_i;
            if      (rd0_i == 5'd28) reg_r28_q <= rd0_value_i;
            else if (rd1_i == 5'd28) reg_r28_q <= rd1_value_i;
            if      (rd0_i == 5'd29) reg_r29_q <= rd0_value_i;
            else if (rd1_i == 5'd29) reg_r29_q <= rd1_value_i;
            if      (rd0_i == 5'd30) reg_r30_q <= rd0_value_i;
            else if (rd1_i == 5'd30) reg_r30_q <= rd1_value_i;
            if      (rd0_i == 5'd31) reg_r31_q <= rd0_value_i;
            else if (rd1_i == 5'd31) reg_r31_q <= rd1_value_i;
        /*  reg_r1_q  <= (rd0_i == 5'd1 ) ? rd0_value_i : reg_r1_q;
            reg_r2_q  <= (rd0_i == 5'd2 ) ? rd0_value_i : reg_r2_q;
            reg_r3_q  <= (rd0_i == 5'd3 ) ? rd0_value_i : reg_r3_q;
            reg_r4_q  <= (rd0_i == 5'd4 ) ? rd0_value_i : reg_r4_q;
            reg_r5_q  <= (rd0_i == 5'd5 ) ? rd0_value_i : reg_r5_q;
            reg_r6_q  <= (rd0_i == 5'd6 ) ? rd0_value_i : reg_r6_q;
            reg_r7_q  <= (rd0_i == 5'd7 ) ? rd0_value_i : reg_r7_q;
            reg_r8_q  <= (rd0_i == 5'd8 ) ? rd0_value_i : reg_r8_q;
            reg_r9_q  <= (rd0_i == 5'd9 ) ? rd0_value_i : reg_r9_q;
            reg_r10_q <= (rd0_i == 5'd10) ? rd0_value_i : reg_r10_q;
            reg_r11_q <= (rd0_i == 5'd11) ? rd0_value_i : reg_r11_q;
            reg_r12_q <= (rd0_i == 5'd12) ? rd0_value_i : reg_r12_q;
            reg_r13_q <= (rd0_i == 5'd13) ? rd0_value_i : reg_r13_q;
            reg_r14_q <= (rd0_i == 5'd14) ? rd0_value_i : reg_r14_q;
            reg_r15_q <= (rd0_i == 5'd15) ? rd0_value_i : reg_r15_q;
            reg_r16_q <= (rd0_i == 5'd16) ? rd0_value_i : reg_r16_q;
            reg_r17_q <= (rd0_i == 5'd17) ? rd0_value_i : reg_r17_q;
            reg_r18_q <= (rd0_i == 5'd18) ? rd0_value_i : reg_r18_q;
            reg_r19_q <= (rd0_i == 5'd19) ? rd0_value_i : reg_r19_q;
            reg_r20_q <= (rd0_i == 5'd20) ? rd0_value_i : reg_r20_q;
            reg_r21_q <= (rd0_i == 5'd21) ? rd0_value_i : reg_r21_q;
            reg_r22_q <= (rd0_i == 5'd22) ? rd0_value_i : reg_r22_q;
            reg_r23_q <= (rd0_i == 5'd23) ? rd0_value_i : reg_r23_q;
            reg_r24_q <= (rd0_i == 5'd24) ? rd0_value_i : reg_r24_q;
            reg_r25_q <= (rd0_i == 5'd25) ? rd0_value_i : reg_r25_q;
            reg_r26_q <= (rd0_i == 5'd26) ? rd0_value_i : reg_r26_q;
            reg_r27_q <= (rd0_i == 5'd27) ? rd0_value_i : reg_r27_q;
            reg_r28_q <= (rd0_i == 5'd28) ? rd0_value_i : reg_r28_q;
            reg_r29_q <= (rd0_i == 5'd29) ? rd0_value_i : reg_r29_q;
            reg_r30_q <= (rd0_i == 5'd30) ? rd0_value_i : reg_r30_q;
            reg_r31_q <= (rd0_i == 5'd31) ? rd0_value_i : reg_r31_q;*/
        end
    end
    //read 
    reg [31:0] ra0_value_r;
    reg [31:0] rb0_value_r;

    always @(*) begin
        case (ra0_i)
            5'd1   : ra0_value_r = reg_r1_q;           
            5'd2   : ra0_value_r = reg_r2_q;           
            5'd3   : ra0_value_r = reg_r3_q;
            5'd4   : ra0_value_r = reg_r4_q;
            5'd5   : ra0_value_r = reg_r5_q;
            5'd6   : ra0_value_r = reg_r6_q;
            5'd7   : ra0_value_r = reg_r7_q;
            5'd8   : ra0_value_r = reg_r8_q;
            5'd9   : ra0_value_r = reg_r9_q;
            5'd10  : ra0_value_r = reg_r10_q;
            5'd11  : ra0_value_r = reg_r11_q;
            5'd12  : ra0_value_r = reg_r12_q;
            5'd13  : ra0_value_r = reg_r13_q;
            5'd14  : ra0_value_r = reg_r14_q;
            5'd15  : ra0_value_r = reg_r15_q;
            5'd16  : ra0_value_r = reg_r16_q;
            5'd17  : ra0_value_r = reg_r17_q;
            5'd18  : ra0_value_r = reg_r18_q;
            5'd19  : ra0_value_r = reg_r19_q;
            5'd20  : ra0_value_r = reg_r20_q;
            5'd21  : ra0_value_r = reg_r21_q;
            5'd22  : ra0_value_r = reg_r22_q;
            5'd23  : ra0_value_r = reg_r23_q;
            5'd24  : ra0_value_r = reg_r24_q;
            5'd25  : ra0_value_r = reg_r25_q;
            5'd26  : ra0_value_r = reg_r26_q;
            5'd27  : ra0_value_r = reg_r27_q;
            5'd28  : ra0_value_r = reg_r28_q;
            5'd29  : ra0_value_r = reg_r29_q;
            5'd30  : ra0_value_r = reg_r30_q;
            5'd31  : ra0_value_r = reg_r31_q;
            default: ra0_value_r = 32'h0;
        endcase

        case (rb0_i)
            5'd1   : rb0_value_r = reg_r1_q;           
            5'd2   : rb0_value_r = reg_r2_q;           
            5'd3   : rb0_value_r = reg_r3_q;
            5'd4   : rb0_value_r = reg_r4_q;
            5'd5   : rb0_value_r = reg_r5_q;
            5'd6   : rb0_value_r = reg_r6_q;
            5'd7   : rb0_value_r = reg_r7_q;
            5'd8   : rb0_value_r = reg_r8_q;
            5'd9   : rb0_value_r = reg_r9_q;
            5'd10  : rb0_value_r = reg_r10_q;
            5'd11  : rb0_value_r = reg_r11_q;
            5'd12  : rb0_value_r = reg_r12_q;
            5'd13  : rb0_value_r = reg_r13_q;
            5'd14  : rb0_value_r = reg_r14_q;
            5'd15  : rb0_value_r = reg_r15_q;
            5'd16  : rb0_value_r = reg_r16_q;
            5'd17  : rb0_value_r = reg_r17_q;
            5'd18  : rb0_value_r = reg_r18_q;
            5'd19  : rb0_value_r = reg_r19_q;
            5'd20  : rb0_value_r = reg_r20_q;
            5'd21  : rb0_value_r = reg_r21_q;
            5'd22  : rb0_value_r = reg_r22_q;
            5'd23  : rb0_value_r = reg_r23_q;
            5'd24  : rb0_value_r = reg_r24_q;
            5'd25  : rb0_value_r = reg_r25_q;
            5'd26  : rb0_value_r = reg_r26_q;
            5'd27  : rb0_value_r = reg_r27_q;
            5'd28  : rb0_value_r = reg_r28_q;
            5'd29  : rb0_value_r = reg_r29_q;
            5'd30  : rb0_value_r = reg_r30_q;
            5'd31  : rb0_value_r = reg_r31_q;
            default: rb0_value_r = 32'h0;
        endcase 
    end
    assign ra0_value_o = ra0_value_r;
    assign rb0_value_o = rb0_value_r;


    reg [31:0] ra1_value_r;
    reg [31:0] rb1_value_r;
    always @(*) begin
        case (ra1_i)
            5'd1   : ra1_value_r = reg_r1_q;           
            5'd2   : ra1_value_r = reg_r2_q;           
            5'd3   : ra1_value_r = reg_r3_q;
            5'd4   : ra1_value_r = reg_r4_q;
            5'd5   : ra1_value_r = reg_r5_q;
            5'd6   : ra1_value_r = reg_r6_q;
            5'd7   : ra1_value_r = reg_r7_q;
            5'd8   : ra1_value_r = reg_r8_q;
            5'd9   : ra1_value_r = reg_r9_q;
            5'd10  : ra1_value_r = reg_r10_q;
            5'd11  : ra1_value_r = reg_r11_q;
            5'd12  : ra1_value_r = reg_r12_q;
            5'd13  : ra1_value_r = reg_r13_q;
            5'd14  : ra1_value_r = reg_r14_q;
            5'd15  : ra1_value_r = reg_r15_q;
            5'd16  : ra1_value_r = reg_r16_q;
            5'd17  : ra1_value_r = reg_r17_q;
            5'd18  : ra1_value_r = reg_r18_q;
            5'd19  : ra1_value_r = reg_r19_q;
            5'd20  : ra1_value_r = reg_r20_q;
            5'd21  : ra1_value_r = reg_r21_q;
            5'd22  : ra1_value_r = reg_r22_q;
            5'd23  : ra1_value_r = reg_r23_q;
            5'd24  : ra1_value_r = reg_r24_q;
            5'd25  : ra1_value_r = reg_r25_q;
            5'd26  : ra1_value_r = reg_r26_q;
            5'd27  : ra1_value_r = reg_r27_q;
            5'd28  : ra1_value_r = reg_r28_q;
            5'd29  : ra1_value_r = reg_r29_q;
            5'd30  : ra1_value_r = reg_r30_q;
            5'd31  : ra1_value_r = reg_r31_q;
            default: ra1_value_r = 32'h0;
        endcase

        case (rb1_i)
            5'd1   : rb1_value_r = reg_r1_q;           
            5'd2   : rb1_value_r = reg_r2_q;           
            5'd3   : rb1_value_r = reg_r3_q;
            5'd4   : rb1_value_r = reg_r4_q;
            5'd5   : rb1_value_r = reg_r5_q;
            5'd6   : rb1_value_r = reg_r6_q;
            5'd7   : rb1_value_r = reg_r7_q;
            5'd8   : rb1_value_r = reg_r8_q;
            5'd9   : rb1_value_r = reg_r9_q;
            5'd10  : rb1_value_r = reg_r10_q;
            5'd11  : rb1_value_r = reg_r11_q;
            5'd12  : rb1_value_r = reg_r12_q;
            5'd13  : rb1_value_r = reg_r13_q;
            5'd14  : rb1_value_r = reg_r14_q;
            5'd15  : rb1_value_r = reg_r15_q;
            5'd16  : rb1_value_r = reg_r16_q;
            5'd17  : rb1_value_r = reg_r17_q;
            5'd18  : rb1_value_r = reg_r18_q;
            5'd19  : rb1_value_r = reg_r19_q;
            5'd20  : rb1_value_r = reg_r20_q;
            5'd21  : rb1_value_r = reg_r21_q;
            5'd22  : rb1_value_r = reg_r22_q;
            5'd23  : rb1_value_r = reg_r23_q;
            5'd24  : rb1_value_r = reg_r24_q;
            5'd25  : rb1_value_r = reg_r25_q;
            5'd26  : rb1_value_r = reg_r26_q;
            5'd27  : rb1_value_r = reg_r27_q;
            5'd28  : rb1_value_r = reg_r28_q;
            5'd29  : rb1_value_r = reg_r29_q;
            5'd30  : rb1_value_r = reg_r30_q;
            5'd31  : rb1_value_r = reg_r31_q;
            default: rb1_value_r = 32'h0;
        endcase
    end
    assign ra1_value_o = ra1_value_r;
    assign rb1_value_o = rb1_value_r;
    
endmodule