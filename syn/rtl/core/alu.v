`include "../core/define.v"
module alu 
(
    input   wire [ 3:0]         alu_op_i        ,
    input   wire [31:0]         alu_a_i         ,
    input   wire [31:0]         alu_b_i         ,
            
    output  wire [31:0]         alu_p_o         
);
    
    reg [31:0] result_r;

    reg [31:0] shift_right_fill_r;
    reg [31:0] shift_right_1_r;
    reg [31:0] shift_right_2_r;
    reg [31:0] shift_right_4_r;
    reg [31:0] shift_right_8_r;
 
    reg [31:0] shift_left_1_r;
    reg [31:0] shift_left_2_r;
    reg [31:0] shift_left_4_r;
    reg [31:0] shift_left_8_r;

    wire [31:0] sub_res_w = alu_a_i - alu_b_i;

    always @(alu_op_i or alu_a_i or alu_b_i or sub_res_w) begin
        shift_right_1_r = 32'h0;
        shift_right_2_r = 32'h0;
        shift_right_4_r = 32'h0;
        shift_right_8_r = 32'h0;
        shift_left_1_r  = 32'h0;
        shift_left_2_r  = 32'h0;
        shift_left_4_r  = 32'h0;
        shift_left_8_r  = 32'h0;        
        case (alu_op_i)
            //左移
            `ALU_SHIFTL : begin
                if (alu_b_i[0] == 1'b1)
                    shift_left_1_r = {alu_a_i[30:0],1'b0};
                else
                    shift_left_1_r = alu_a_i;

                if (alu_b_i[1] == 1'b1)
                    shift_left_2_r = {shift_left_1_r[29:0],2'b00};
                else
                    shift_left_2_r = shift_left_1_r;

                if (alu_b_i[2] == 1'b1)
                    shift_left_4_r = {shift_left_2_r[27:0],4'b0000};
                else
                    shift_left_4_r = shift_left_2_r;

                if (alu_b_i[3] == 1'b1)
                    shift_left_8_r = {shift_left_4_r[23:0],8'b00000000};
                else
                    shift_left_8_r = shift_left_4_r;

                if (alu_b_i[4] == 1'b1)
                    result_r = {shift_left_8_r[15:0],16'b0000000000000000};
                else
                    result_r = shift_left_8_r;
            end
            //右移
            `ALU_SHIFTR, `ALU_SHIFTR_ARITH : begin
            // 先判断右移类型
            if (alu_a_i[31] == 1'b1 && alu_op_i == `ALU_SHIFTR_ARITH)
                shift_right_fill_r = 32'hffff_ffff;
            else
                shift_right_fill_r = 32'h0000_0000;

            if (alu_b_i[0] == 1'b1)
                shift_right_1_r = {shift_right_fill_r[31], alu_a_i[31:1]};
            else
                shift_right_1_r = alu_a_i;

            if (alu_b_i[1] == 1'b1)
                shift_right_2_r = {shift_right_fill_r[31:30], shift_right_1_r[31:2]};
            else
                shift_right_2_r = shift_right_1_r;

            if (alu_b_i[2] == 1'b1)
                shift_right_4_r = {shift_right_fill_r[31:28], shift_right_2_r[31:4]};
            else
                shift_right_4_r = shift_right_2_r;

            if (alu_b_i[3] == 1'b1)
                shift_right_8_r = {shift_right_fill_r[31:24], shift_right_4_r[31:8]};
            else
                shift_right_8_r = shift_right_4_r;

            if (alu_b_i[4] == 1'b1)
                result_r = {shift_right_fill_r[31:16], shift_right_8_r[31:16]};
            else
                result_r = shift_right_8_r;
            end
            //算术运算
            `ALU_ADD : result_r = alu_a_i + alu_b_i;
            `ALU_SUB : result_r = sub_res_w;
            //逻辑运算 
            `ALU_AND : result_r = (alu_a_i & alu_b_i);
            `ALU_OR  : result_r = alu_a_i | alu_b_i;
            `ALU_XOR : result_r = alu_a_i ^ alu_b_i;
            //比较运算
            `ALU_LESS_THAN : result_r = (alu_a_i < alu_b_i) ? 32'h1 : 32'h0;
            `ALU_LESS_THAN_SIGNED : begin
                if (alu_a_i[31] != alu_b_i[31])
                    result_r  = alu_a_i[31] ? 32'h1 : 32'h0;
                else
                    result_r  = sub_res_w[31] ? 32'h1 : 32'h0;   
            end

            default  : result_r = alu_a_i;
        endcase
    end

    assign alu_p_o = result_r;

endmodule