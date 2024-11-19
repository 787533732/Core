`include "../core/define.v"
module multiplier 
#(
    parameter MULT_STAGES = 2//计算周期可以是2或3
)
(
    input   wire            clk_i               ,
    input   wire            rstn_i              ,
    input   wire            opcode_valid_i      ,
    input   wire [31:0]     opcode_opcode_i     ,
    input   wire [31:0]     opcode_ra_operand_i ,
    input   wire [31:0]     opcode_rb_operand_i ,
    input   wire            hold_i              ,

    output  wire [31:0]     writeback_value_o
);

    reg  [32:0] operand_a_r;
    reg  [32:0] operand_b_r;
    wire [64:0] mult_result_w;
    wire [31:0] result_w;

    wire mult_inst_w = ((opcode_opcode_i & `INST_MUL_MASK)     == `INST_MUL)   ||
                       ((opcode_opcode_i & `INST_MULH_MASK)    == `INST_MULH)  ||
                       ((opcode_opcode_i & `INST_MULHU_MASK)   == `INST_MULHU) ||
                       ((opcode_opcode_i & `INST_MULHSU_MASK)  == `INST_MULHSU);

    always @(*) begin
        if((opcode_opcode_i & `INST_MULHSU_MASK) == `INST_MULHSU)
            operand_a_r = {opcode_ra_operand_i[31], opcode_ra_operand_i[31:0]};
        else if((opcode_opcode_i & `INST_MULH_MASK) == `INST_MULH) 
            operand_a_r = {opcode_ra_operand_i[31], opcode_ra_operand_i[31:0]};
        else
            operand_a_r = {1'b0, opcode_ra_operand_i[31:0]};
    end

    always @(*) begin
        if((opcode_opcode_i & `INST_MULHSU_MASK) == `INST_MULHSU) 
            operand_b_r = {1'b0, opcode_rb_operand_i[31:0]};
        else if((opcode_opcode_i & `INST_MULH_MASK) == `INST_MULH) 
            operand_b_r = {opcode_rb_operand_i[31], opcode_rb_operand_i[31:0]};
        else
            operand_b_r = {1'b0, opcode_rb_operand_i[31:0]};
    end

    reg [32:0]  operand_a_e1_q;
    reg [32:0]  operand_b_e1_q;
    reg         mulhi_sel_e1_q;    

    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            operand_a_e1_q <= 33'd0;
            operand_b_e1_q <= 33'd0;
            mulhi_sel_e1_q <= 1'b0;
        end 
        else if(hold_i) begin
            operand_a_e1_q <= operand_a_e1_q;
            operand_b_e1_q <= operand_b_e1_q;
            mulhi_sel_e1_q <= mulhi_sel_e1_q;
        end
        else if(opcode_valid_i && mult_inst_w) begin
            operand_a_e1_q <= operand_a_r;
            operand_b_e1_q <= operand_b_r;
            mulhi_sel_e1_q <= ~((opcode_opcode_i & `INST_MUL_MASK) == `INST_MUL);
        end
        else begin
            operand_a_e1_q <= 33'd0;
            operand_b_e1_q <= 33'd0;
            mulhi_sel_e1_q <= 1'b0;
        end
    end

    assign mult_result_w = {{32{operand_a_e1_q[32]}}, operand_a_e1_q} * {{32{operand_b_e1_q[32]}}, operand_b_e1_q};

    assign result_w     = mulhi_sel_e1_q ? mult_result_w[63:32] : mult_result_w[31:0];


    generate
        if(MULT_STAGES == 2) begin
            reg [31:0] result_e2_q;
            always @(posedge clk_i or negedge rstn_i) begin
                if(!rstn_i)
                    result_e2_q <= 32'd0;
                else if(~hold_i)
                    result_e2_q <= result_w;
            end

            assign writeback_value_o = result_e2_q;
        end
        else if(MULT_STAGES == 3) begin
            reg [31:0] result_e3_q;
            reg [31:0] result_e2_q;
            always @(posedge clk_i or negedge rstn_i) begin
                if(!rstn_i)
                    result_e2_q <= 32'd0;
                else if(~hold_i)
                    result_e2_q <= result_w;
            end

            always @(posedge clk_i or negedge rstn_i) begin
                if(!rstn_i)
                    result_e3_q <= 32'd0;
                else if(~hold_i)
                    result_e3_q <= result_e2_q;
            end
            assign writeback_value_o = result_e3_q;
        end
    endgenerate
//-----------------------------------------------------------------
// 改进：用Generate，在不同配置下生成不同电路，节省面积
//-----------------------------------------------------------------
/*
reg [31:0] result_e2_q;
reg [31:0] result_e3_q;
always @(posedge clk_i or posedge rstn_i)
if (rstn_i)
    result_e2_q <= 32'b0;
else if (~hold_i)
    result_e2_q <= result_w;

always @(posedge clk_i or posedge rstn_i)
if (rstn_i)
    result_e3_q <= 32'b0;
else if (~hold_i)
    result_e3_q <= result_e2_q;

assign writeback_value_o  = (MULT_STAGES == 3) ? result_e3_q : result_e2_q;
*/

endmodule