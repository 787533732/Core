`include "../core/define.v"
module divider 
(
    input   wire            clk_i               ,
    input   wire            rstn_i              ,
    input   wire            opcode_valid_i      ,
    input   wire [31:0]     opcode_opcode_i     ,
    input   wire [31:0]     opcode_ra_operand_i ,
    input   wire [31:0]     opcode_rb_operand_i ,

    output  wire            writeback_valid_o   ,
    output  wire [31:0]     writeback_value_o
);

    wire inst_div_w     = (opcode_opcode_i & `INST_DIV_MASK)  == `INST_DIV;
    wire inst_divu_w    = (opcode_opcode_i & `INST_DIVU_MASK) == `INST_DIVU;
    wire inst_rem_w     = (opcode_opcode_i & `INST_REM_MASK)  == `INST_REM;
    wire inst_remu_w    = (opcode_opcode_i & `INST_REMU_MASK) == `INST_REMU;

    wire div_rem_inst_w = ((opcode_opcode_i & `INST_DIV_MASK)  == `INST_DIV) || 
                          ((opcode_opcode_i & `INST_DIVU_MASK) == `INST_DIVU)||
                          ((opcode_opcode_i & `INST_REM_MASK)  == `INST_REM) ||
                          ((opcode_opcode_i & `INST_REMU_MASK) == `INST_REMU);
    
    wire signed_operation_w = ((opcode_opcode_i & `INST_DIV_MASK)  == `INST_DIV) || ((opcode_opcode_i & `INST_REM_MASK)  == `INST_REM);
    wire div_operation_w    = ((opcode_opcode_i & `INST_DIV_MASK)  == `INST_DIV) || ((opcode_opcode_i & `INST_DIVU_MASK) == `INST_DIVU);
    
    reg         div_inst_q;
    reg         div_busy_q;
    reg [31:0]  dividend_q;//被除数
    reg [62:0]  divisor_q;  //除数
    reg         invert_res_q;//负数除法会用到
    reg [31:0]  quotient_q;
    reg [31:0]  q_mask_q;  
    reg [31:0]  last_a_q;   
    reg [31:0]  last_b_q;   
    reg         last_div_q; 
    reg         last_divu_q;
    reg         last_rem_q; 
    reg         last_remu_q;

    wire div_start_w    = opcode_valid_i && div_rem_inst_w;
    wire div_complete_w = !(|q_mask_q) && div_busy_q;

    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            div_busy_q   <= 1'b0;
            dividend_q   <= 32'b0;
            divisor_q    <= 63'b0;
            invert_res_q <= 1'b0;
            quotient_q   <= 32'b0;
            q_mask_q     <= 32'b0;
            last_a_q     <= 32'b0;
            last_b_q     <= 32'b0;
            last_div_q   <= 1'b0;
            last_divu_q  <= 1'b0;
            last_rem_q   <= 1'b0;
            last_remu_q  <= 1'b0;
        end
        else if(div_start_w) begin
            if(last_a_q    == opcode_ra_operand_i 
            && last_b_q    == opcode_rb_operand_i 
            && last_div_q  == inst_div_w 
            && last_divu_q == inst_divu_w         
            && last_rem_q  == inst_rem_w          
            && last_remu_q == inst_remu_w)
                div_busy_q <= 1'b1;//如果上一次的操作数以及操作指令和现在相同，说明还在继续进行运算
            else begin
                last_a_q    <= opcode_ra_operand_i;
                last_b_q    <= opcode_rb_operand_i;
                last_div_q  <= inst_div_w;
                last_divu_q <= inst_divu_w;
                last_rem_q  <= inst_rem_w;
                last_remu_q <= inst_remu_w;
                div_busy_q  <= 1'b1;
                div_inst_q  <= div_operation_w;
                //被除数
                if(signed_operation_w && opcode_ra_operand_i[31])//ra是负数
                    dividend_q <= -opcode_ra_operand_i;
                else 
                    dividend_q <= opcode_ra_operand_i;
                //除数
                if(signed_operation_w && opcode_rb_operand_i[31])
                    divisor_q  <= {-opcode_rb_operand_i, 31'b0};
                else 
                    divisor_q  <= {opcode_rb_operand_i, 31'b0};  

                invert_res_q <= (((opcode_opcode_i & `INST_DIV_MASK) == `INST_DIV) && (opcode_ra_operand_i[31] != opcode_rb_operand_i[31]) && |opcode_rb_operand_i)//被除数和除数符号，且除数非0  
                             || (((opcode_opcode_i & `INST_REM_MASK) == `INST_REM) && opcode_ra_operand_i[31]);
                quotient_q   <= 32'b0;
                q_mask_q     <= 32'h8000_0000;
            end
        end
        else if(div_complete_w)
            div_busy_q <= 1'b0;
        else if(div_busy_q) begin
            if(divisor_q <= {31'b0, dividend_q}) begin
                dividend_q <= dividend_q - divisor_q[31:0];
                quotient_q <= quotient_q | q_mask_q;
            end     
            divisor_q <= {1'b0, divisor_q[62:1]};
            q_mask_q  <= {1'b0, q_mask_q[31:1]};
        end
    end

        reg[31:0] div_result_r;
        always @(*) begin
            div_result_r = 32'b0;
            if(div_inst_q)
                div_result_r = invert_res_q ? -quotient_q : quotient_q;//除法指令得到商
            else
                div_result_r = invert_res_q ? -dividend_q : dividend_q;//取余指令得到余数
        end
        
        reg valid_q;
        always @(posedge clk_i or negedge rstn_i) begin
            if(!rstn_i)
                valid_q <= 1'b0;
            else 
                valid_q <= div_complete_w;
        end

        reg [31:0] wb_result_q;
        always @(posedge clk_i or negedge rstn_i) begin
            if(!rstn_i)
                wb_result_q <= 32'b0;
            else if(div_complete_w)
                wb_result_q <= div_result_r;
        end

    assign writeback_valid_o = valid_q;
    assign writeback_value_o = wb_result_q;
    
endmodule