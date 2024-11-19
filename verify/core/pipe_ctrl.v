`include "../core/define.v"
`define PCINFO_W         10
`define PCINFO_ALU       0
`define PCINFO_LOAD      1
`define PCINFO_STORE     2
`define PCINFO_CSR       3
`define PCINFO_DIV       4
`define PCINFO_MUL       5
`define PCINFO_BRANCH    6
`define PCINFO_RD_VALID  7
`define PCINFO_INTR      8
`define PCINFO_COMPLETE  9
`define RD_IDX_R         11:7
//主要是～选择～逻辑，通过划分E1、E2、WB三级，逐级准备好数据，同时引入前馈提前获得数据
module pipe_ctrl 
#(
    parameter   SUPPORT_LOAD_BYPASS = 1,
    parameter   SUPPORT_MUL_BYPASS  = 1
)
(
    input   wire                clk_i                       ,
    input   wire                rstn_i                      ,

    input   wire                issue_valid_i               ,
    input   wire                issue_accept_i              ,
    input   wire                issue_stall_i               ,
    //issue输入，打1/2拍输出
    input   wire [ 4:0]         issue_rd_i                  ,//useless
    input   wire                issue_rd_valid_i            ,
    input   wire                issue_lsu_i                 ,
    input   wire                issue_csr_i                 ,
    input   wire                issue_div_i                 ,
    input   wire                issue_mul_i                 ,
    input   wire                issue_branch_i              ,
    input   wire [ 5:0]         issue_exception_i           ,
    input   wire [31:0]         issue_pc_i                  ,
    input   wire [31:0]         issue_opcode_i              ,
    input   wire [31:0]         issue_operand_ra_i          ,
    input   wire [31:0]         issue_operand_rb_i          ,
    input   wire                issue_branch_taken_i        ,
    input   wire [31:0]         issue_branch_target_i       , 
    input   wire                take_interrupt_i            ,
    //----------------------------E1----------------------------Pre-decode和Issue间的第二级流水线寄存器
    //ALU，CSR result计算用一个周期
    input   wire [31:0]         alu_result_e1_i             ,
    input   wire [31:0]         csr_result_value_e1_i       ,
    input   wire                csr_result_write_e1_i       ,
    input   wire [31:0]         csr_result_wdata_e1_i       ,
    input   wire [ 5:0]         csr_result_exception_e1_i   ,
    //issue(decode)输入打一拍
    output  wire                load_e1_o                   ,
    output  wire                store_e1_o                  ,
    output  wire                mul_e1_o                    ,
    output  wire                branch_e1_o                 ,
    output  wire [ 4:0]         rd_e1_o                     ,
    output  wire [31:0]         pc_e1_o                     ,
    output  wire [31:0]         opcode_e1_o                 ,
    output  wire [31:0]         operand_ra_e1_o             ,
    output  wire [31:0]         operand_rb_e1_o             ,
    //----------------------------E2----------------------------E1和E2间的第三级流水线寄存器
    //一个两个周期，计算用一个周期，访存用一个周期
    input   wire                mem_complete_i              ,
    input   wire [31:0]         mem_result_e2_i             ,                   
    input   wire [ 5:0]         mem_exception_e2_i          ,
    input   wire [31:0]         mul_result_e2_i             ,
    //issue(decode)输入打两拍
    output  wire                load_e2_o                   ,
    output  wire                mul_e2_o                    ,
    output  wire [ 4:0]         rd_e2_o                     ,//其中3个信号打两拍
    output  wire [31:0]         result_e2_o                 ,

    output  wire                stall_o                     ,
    output  wire                squash_e1_e2_o              ,
    input   wire                squash_e1_e2_i              ,
    input   wire                squash_wb_i                 ,
    //除法结果不参与顺序执行，只要写好了就输入，除法会暂停流水线
    input   wire                div_complete_i              ,
    input   wire [31:0]         div_result_i                ,
    //----------------------------WB----------------------------E2和WB之间的第四级流水线寄存器
    output  wire                valid_wb_o                  ,
    output  wire                csr_wb_o                    ,
    output  wire [ 4:0]         rd_wb_o                     ,
    output  wire [31:0]         result_wb_o                 ,
    output  wire [31:0]         pc_wb_o                     ,
    output  wire [31:0]         opcode_wb_o                 ,   
    output  wire [31:0]         operand_ra_wb_o             ,
    output  wire [31:0]         operand_rb_wb_o             ,
    output  wire [ 5:0]         exception_wb_o              ,
    
    output  wire                csr_write_wb_o              ,
    output  wire [11:0]         csr_waddr_wb_o              ,
    output  wire [31:0]         csr_wdata_wb_o               


);
    wire branch_misaligned_w = (issue_branch_taken_i && issue_branch_target_i[1:0] != 2'b0);//跳转到非对齐的地址
    //输入打一拍（第二级流水线寄存器）
    reg                     valid_e1_q;
    reg [`PCINFO_W-1:0]     ctrl_e1_q;
    reg [31:0]              pc_e1_q;
    reg [31:0]              npc_e1_q;
    reg [31:0]              opcode_e1_q;
    reg [31:0]              operand_ra_e1_q;
    reg [31:0]              operand_rb_e1_q;
    reg [`EXCEPTION_W-1:0]  exception_e1_q;//错误信息
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            valid_e1_q      <= 1'b0;
            ctrl_e1_q       <= `PCINFO_W'b0;
            pc_e1_q         <= 32'h0;
            npc_e1_q        <= 32'h0;
            opcode_e1_q     <= 32'h0;
            operand_ra_e1_q <= 32'h0;
            operand_rb_e1_q <= 32'h0;
            exception_e1_q  <= `EXCEPTION_W'b0;
        end
        else if(issue_stall_i) begin//暂停输出保持不变
            valid_e1_q      <= valid_e1_q;     
            ctrl_e1_q       <= ctrl_e1_q;      
            pc_e1_q         <= pc_e1_q;        
            npc_e1_q        <= npc_e1_q;       
            opcode_e1_q     <= opcode_e1_q;    
            operand_ra_e1_q <= operand_ra_e1_q;
            operand_rb_e1_q <= operand_rb_e1_q;
            exception_e1_q  <= exception_e1_q; 
        end
        else if((issue_valid_i && issue_accept_i) && ~(squash_e1_e2_o) && ~(squash_e1_e2_i)) begin//其实就是打一拍输出
            valid_e1_q                  <= 1'b1;
            ctrl_e1_q[`PCINFO_ALU]      <= (~issue_lsu_i)   && (~issue_csr_i)      && (~issue_div_i) && (~issue_mul_i);
            ctrl_e1_q[`PCINFO_LOAD]     <= issue_lsu_i      && issue_rd_valid_i    && (~take_interrupt_i);
            ctrl_e1_q[`PCINFO_STORE]    <= issue_lsu_i      && (~issue_rd_valid_i) && (~take_interrupt_i);
            ctrl_e1_q[`PCINFO_CSR]      <= issue_csr_i      && (~take_interrupt_i);
            ctrl_e1_q[`PCINFO_DIV]      <= issue_div_i      && (~take_interrupt_i);
            ctrl_e1_q[`PCINFO_MUL]      <= issue_mul_i      && (~take_interrupt_i);
            ctrl_e1_q[`PCINFO_BRANCH]   <= issue_branch_i   && (~take_interrupt_i);
            ctrl_e1_q[`PCINFO_RD_VALID] <= issue_rd_valid_i && (~take_interrupt_i);
            ctrl_e1_q[`PCINFO_INTR]     <= take_interrupt_i;
            ctrl_e1_q[`PCINFO_COMPLETE] <= 1'b1;
            pc_e1_q                     <= issue_pc_i;
            npc_e1_q                    <= issue_branch_taken_i ? issue_branch_target_i : issue_pc_i + 32'd4;
            opcode_e1_q                 <= issue_opcode_i;
            operand_ra_e1_q             <= issue_operand_ra_i;
            operand_rb_e1_q             <= issue_operand_rb_i;
            exception_e1_q              <= (|issue_exception_i) ? issue_exception_i :
                                            branch_misaligned_w ? `EXCEPTION_MISALIGNED_FETCH : `EXCEPTION_W'b0;
        end
        //无有效指令or流水线正在冲刷
        else begin
            valid_e1_q      <= 1'b0;     
            ctrl_e1_q       <= `PCINFO_W'h0;      
            pc_e1_q         <= 32'h0;
            npc_e1_q        <= 32'h0;
            opcode_e1_q     <= 32'h0;
            operand_ra_e1_q <= 32'h0;
            operand_rb_e1_q <= 32'h0;
            exception_e1_q  <= `EXCEPTION_W'h0; 
        end
    end

    wire    alu_e1_w        = ctrl_e1_q[`PCINFO_ALU];
    wire    csr_e1_w        = ctrl_e1_q[`PCINFO_CSR];
    wire    div_e1_w        = ctrl_e1_q[`PCINFO_DIV];

    assign  load_e1_o       = ctrl_e1_q[`PCINFO_LOAD];
    assign  store_e1_o      = ctrl_e1_q[`PCINFO_STORE];
    assign  mul_e1_o        = ctrl_e1_q[`PCINFO_MUL];
    assign  branch_e1_o     = ctrl_e1_q[`PCINFO_BRANCH];    
    assign  rd_e1_o         = {5{ctrl_e1_q[`PCINFO_RD_VALID]}} & opcode_e1_q[`RD_IDX_R];
    assign  pc_e1_o         = pc_e1_q;
    assign  opcode_e1_o     = opcode_e1_q;
    assign  operand_ra_e1_o = operand_ra_e1_q;
    assign  operand_rb_e1_o = operand_rb_e1_q;
//-------------------------------------------------------------
// E2 / Mem result
//------------------------------------------------------------- 
    reg                     valid_e2_q;
    reg [`PCINFO_W-1:0]     ctrl_e2_q;
    reg                     csr_wr_e2_q;
    reg [31:0]              csr_wdata_e2_q;
    reg [31:0]              result_e2_q;
    reg [31:0]              pc_e2_q;
    reg [31:0]              npc_e2_q;
    reg [31:0]              opcode_e2_q;
    reg [31:0]              operand_ra_e2_q;
    reg [31:0]              operand_rb_e2_q;
    reg [`EXCEPTION_W-1:0]  exception_e2_q;

    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            valid_e2_q      <= 1'b0;
            ctrl_e2_q       <= `PCINFO_W'h0;
            csr_wr_e2_q     <= 1'b0;
            csr_wdata_e2_q  <= 32'h0;
            pc_e2_q         <= 32'h0;
            npc_e2_q        <= 32'h0;
            opcode_e2_q     <= 32'h0;
            operand_ra_e2_q <= 32'h0;
            operand_rb_e2_q <= 32'h0;
            result_e2_q     <= 32'h0;
            exception_e2_q  <= `EXCEPTION_W'h0;
        end 
        else if(issue_stall_i) begin//流水线暂停
            valid_e2_q      <= valid_e2_q;     
            ctrl_e2_q       <= ctrl_e2_q;      
            csr_wr_e2_q     <= csr_wr_e2_q;    
            csr_wdata_e2_q  <= csr_wdata_e2_q; 
            pc_e2_q         <= pc_e2_q;        
            npc_e2_q        <= npc_e2_q;       
            opcode_e2_q     <= opcode_e2_q;    
            operand_ra_e2_q <= operand_ra_e2_q;
            operand_rb_e2_q <= operand_rb_e2_q;
            result_e2_q     <= result_e2_q;    
            exception_e2_q  <= exception_e2_q; 
        end
        else if(squash_e1_e2_o || squash_e1_e2_i) begin//流水线冲刷
            valid_e2_q      <= 1'b0;
            ctrl_e2_q       <= `PCINFO_W'h0;
            csr_wr_e2_q     <= 1'b0;
            csr_wdata_e2_q  <= 32'h0;
            pc_e2_q         <= 32'h0;
            npc_e2_q        <= 32'h0;
            opcode_e2_q     <= 32'h0;
            operand_ra_e2_q <= 32'h0;
            operand_rb_e2_q <= 32'h0;
            result_e2_q     <= 32'h0;
            exception_e2_q  <= `EXCEPTION_W'h0;
        end 
        else begin
            valid_e2_q      <= valid_e1_q;     
            ctrl_e2_q       <= ctrl_e1_q;      
            csr_wr_e2_q     <= csr_result_write_e1_i;    
            csr_wdata_e2_q  <= csr_result_wdata_e1_i; 
            pc_e2_q         <= pc_e1_q;        
            npc_e2_q        <= npc_e1_q;       
            opcode_e2_q     <= opcode_e1_q;    
            operand_ra_e2_q <= operand_ra_e1_q;
            operand_rb_e2_q <= operand_rb_e1_q;
              
            if(ctrl_e1_q[`PCINFO_INTR])
                exception_e2_q  <= `EXCEPTION_INTERRUPT;
            else if(|exception_e1_q) begin//发生错误指令无效，忽略csr错误
                valid_e2_q      <= 1'b0;
                exception_e2_q  <= exception_e1_q;
            end
            else
                exception_e2_q  <= csr_result_exception_e1_i;
            
            if(ctrl_e1_q[`PCINFO_DIV])
                result_e2_q     <= div_result_i;
            else if(ctrl_e1_q[`PCINFO_CSR])
                result_e2_q     <= csr_result_value_e1_i;
            else 
                result_e2_q     <= alu_result_e1_i;
        end
    end

    reg [31:0]  result_e2_r;
    wire valid_e2_w = valid_e2_q & ~issue_stall_i;

    wire load_store_e2_w = ctrl_e2_q[`PCINFO_LOAD] || ctrl_e2_q[`PCINFO_STORE];
    always @(*) begin
       //Default:ALU
        result_e2_r = result_e2_q;
        if(SUPPORT_LOAD_BYPASS && valid_e2_w && load_store_e2_w) 
            result_e2_r = mem_result_e2_i;
        else if(SUPPORT_MUL_BYPASS && valid_e2_w && ctrl_e2_q[`PCINFO_MUL])
            result_e2_r = mul_result_e2_i;
    end

    assign load_e2_o       = ctrl_e2_q[`PCINFO_LOAD];
    assign mul_e2_o        = ctrl_e2_q[`PCINFO_MUL];
    assign rd_e2_o         = {5{(valid_e2_w && ctrl_e2_q[`PCINFO_RD_VALID] && ~stall_o)}} & opcode_e2_q[`RD_IDX_R];
    assign result_e2_o     = result_e2_r;
    //LoadStore/Div结果还没完成
    assign stall_o = (ctrl_e1_q[`PCINFO_DIV] && ~div_complete_i) || ((ctrl_e2_q[`PCINFO_LOAD] | ctrl_e2_q[`PCINFO_STORE]) & ~mem_complete_i);

    reg [`EXCEPTION_W-1:0] exception_e2_r;
    always @(*) begin
        if(valid_e2_q && (ctrl_e2_q[`PCINFO_LOAD] || ctrl_e2_q[`PCINFO_STORE]) && mem_complete_i)
            exception_e2_r = mem_exception_e2_i;
        else
            exception_e2_r = exception_e2_q;
    end

    assign squash_e1_e2_w = |exception_e2_r;

    reg squash_e1_e2_q;
    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i)
            squash_e1_e2_q <= 1'b0;
        else if(!issue_stall_i)
            squash_e1_e2_q <= squash_e1_e2_w;
    end

    assign squash_e1_e2_o = squash_e1_e2_w | squash_e1_e2_q;//2 cycle
    //write back
    reg                     valid_wb_q;
    reg [`PCINFO_W-1:0]     ctrl_wb_q;
    reg                     csr_wr_wb_q;
    reg [31:0]              csr_wdata_wb_q;
    reg [31:0]              result_wb_q;
    reg [31:0]              pc_wb_q;
    reg [31:0]              npc_wb_q;
    reg [31:0]              opcode_wb_q;
    reg [31:0]              operand_ra_wb_q;
    reg [31:0]              operand_rb_wb_q;
    reg [`EXCEPTION_W-1:0]  exception_wb_q;

    always @(posedge clk_i or negedge rstn_i) begin
        if(!rstn_i) begin
            valid_wb_q      <= 1'b0;
            ctrl_wb_q       <= `PCINFO_W'h0;
            csr_wr_wb_q     <= 1'b0;
            csr_wdata_wb_q  <= 32'h0;
            pc_wb_q         <= 32'h0;
            npc_wb_q        <= 32'h0;
            opcode_wb_q     <= 32'h0;
            operand_ra_wb_q <= 32'h0;
            operand_rb_wb_q <= 32'h0;
            result_wb_q     <= 32'h0;
            exception_wb_q  <= `EXCEPTION_W'h0;
        end
        else if(issue_stall_i) begin
            valid_wb_q      <= valid_wb_q;     
            ctrl_wb_q       <= ctrl_wb_q;      
            csr_wr_wb_q     <= csr_wr_wb_q;    
            csr_wdata_wb_q  <= csr_wdata_wb_q; 
            pc_wb_q         <= pc_wb_q;        
            npc_wb_q        <= npc_wb_q;       
            opcode_wb_q     <= opcode_wb_q;    
            operand_ra_wb_q <= operand_ra_wb_q;
            operand_rb_wb_q <= operand_rb_wb_q;
            result_wb_q     <= result_wb_q;    
            exception_wb_q  <= exception_wb_q;
        end
        else if(squash_wb_i) begin
            valid_wb_q      <= 1'b0;
            ctrl_wb_q       <= `PCINFO_W'h0;
            csr_wr_wb_q     <= 1'b0;
            csr_wdata_wb_q  <= 32'h0;
            pc_wb_q         <= 32'h0;
            npc_wb_q        <= 32'h0;
            opcode_wb_q     <= 32'h0;
            operand_ra_wb_q <= 32'h0;
            operand_rb_wb_q <= 32'h0;
            result_wb_q     <= 32'h0;
            exception_wb_q  <= `EXCEPTION_W'h0;
        end  
        else begin
            case (exception_e2_r)
                `EXCEPTION_MISALIGNED_LOAD,
                `EXCEPTION_FAULT_LOAD,
                `EXCEPTION_MISALIGNED_STORE,
                `EXCEPTION_FAULT_STORE,
                `EXCEPTION_PAGE_FAULT_LOAD,
                `EXCEPTION_PAGE_FAULT_STORE:
                    valid_wb_q <= 1'b0; 
                default: 
                    valid_wb_q <= valid_e2_q;
            endcase
            csr_wr_wb_q    <= csr_wr_e2_q;
            csr_wdata_wb_q <= csr_wdata_e2_q;

            if(|exception_e2_r)
                ctrl_wb_q <= ctrl_e2_q & ~ (1 << `PCINFO_RD_VALID);//??
            else
                ctrl_wb_q <= ctrl_e2_q;

            pc_wb_q         <= pc_e2_q;
            npc_wb_q        <= npc_e2_q;
            opcode_wb_q     <= opcode_e2_q;
            operand_ra_wb_q <= operand_ra_e2_q;
            operand_rb_wb_q <= operand_rb_e2_q;
            exception_wb_q  <= exception_e2_r;

            if(valid_e2_w && (ctrl_e2_q[`PCINFO_LOAD] || ctrl_e2_q[`PCINFO_STORE]))
                result_wb_q <= mem_result_e2_i;
            else if(valid_e2_w && ctrl_e2_q[`PCINFO_MUL])
                result_wb_q <= mul_result_e2_i;
            else
                result_wb_q <= result_e2_q;
        end   
    end
    //debug
    wire   complete_wb_w    = ctrl_wb_q[`PCINFO_COMPLETE] & ~issue_stall_i;

    assign valid_wb_o       = valid_wb_q & ~issue_stall_i;
    assign csr_wb_o         = ctrl_wb_q[`PCINFO_CSR] & ~issue_stall_i;
    assign rd_wb_o          = {5{(valid_wb_o && ctrl_wb_q[`PCINFO_RD_VALID] && ~stall_o)}} & opcode_wb_q[`RD_IDX_R];
    assign result_wb_o      = result_wb_q;
    assign pc_wb_o          = pc_wb_q;
    assign opcode_wb_o      = opcode_wb_q;
    assign operand_ra_wb_o  = operand_ra_wb_q;
    assign operand_rb_wb_o  = operand_rb_wb_q;
    assign exception_wb_o   = exception_wb_q;

    assign csr_write_wb_o   = csr_wr_wb_q;
    assign csr_waddr_wb_o   = opcode_wb_q[31:20];
    assign csr_wdata_wb_o   = csr_wdata_wb_q;

endmodule