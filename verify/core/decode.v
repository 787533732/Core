//fifo存放数据，输出给两个指令解码器
module decode 
#(
    parameter SUPPORT_MULDIV     = 1,
    parameter EXTRA_DECODE_STAGE = 0
 
) (
    input   wire            clk_i                       ,
    input   wire            rstn_i                      ,
    input   wire            branch_request_i            ,//预测失败冲刷请求
    input   wire [63:0]     fetch_in_instr_i            ,//i-cache取的64位指令
    input   wire            fetch_in_valid_i            ,//取指请求有效
    input   wire            fetch_in_fault_fetch_i      ,//两个取指错误信号
    input   wire            fetch_in_fault_page_i       ,
    input   wire [1:0]      fetch_in_pred_branch_i      ,//预测的跳转情况
    input   wire [31:0]     fetch_in_pc_i               ,//发出取指请求的PC
    input   wire            fetch_out0_accept_i         ,//与下个模块握手
    input   wire            fetch_out1_accept_i         ,

    output  wire            fetch_in_accept_o           ,
    //chanel0
    output  wire [31:0]     fetch_out0_instr_o          ,//指令0
    output  wire            fetch_out0_valid_o          ,
    output  wire            fetch_out0_fault_fetch_o    ,
    output  wire            fetch_out0_fault_page_o     ,
    output  wire [31:0]     fetch_out0_pc_o             ,
    output  wire            fetch_out0_instr_invalid_o  ,
    output  wire            fetch_out0_instr_exec_o     ,           
    output  wire            fetch_out0_instr_lsu_o      ,
    output  wire            fetch_out0_instr_branch_o   ,
    output  wire            fetch_out0_instr_mul_o      ,      
    output  wire            fetch_out0_instr_div_o      ,
    output  wire            fetch_out0_instr_csr_o      ,
    output  wire            fetch_out0_instr_rs1_valid_o,
    output  wire            fetch_out0_instr_rs2_valid_o,
    output  wire            fetch_out0_instr_rd_valid_o ,
    //chanel1
    output  wire [31:0]     fetch_out1_instr_o          ,//指令1
    output  wire            fetch_out1_valid_o          ,
    output  wire            fetch_out1_fault_fetch_o    ,
    output  wire            fetch_out1_fault_page_o     ,
    output  wire [31:0]     fetch_out1_pc_o             ,
    output  wire            fetch_out1_instr_invalid_o  ,
    output  wire            fetch_out1_instr_exec_o     ,           
    output  wire            fetch_out1_instr_lsu_o      ,
    output  wire            fetch_out1_instr_branch_o   ,
    output  wire            fetch_out1_instr_mul_o      ,      
    output  wire            fetch_out1_instr_div_o      ,
    output  wire            fetch_out1_instr_csr_o      ,
    output  wire            fetch_out1_instr_rs1_valid_o,
    output  wire            fetch_out1_instr_rs2_valid_o,
    output  wire            fetch_out1_instr_rd_valid_o 
);

wire enable_muldiv_w = SUPPORT_MULDIV;

generate
    if(EXTRA_DECODE_STAGE) begin

    end 
//-----------------------------------------------------------------
// 反压用的fifo
//-----------------------------------------------------------------
    else begin

    wire [63:0] fifo_instr_i = (fetch_in_fault_fetch_i | fetch_in_fault_page_i) ? 64'h0 : fetch_in_instr_i;
//如果fifo深度为1，fifo就处于一个非满即空的状态，满的时候不能写入，空的时候不能读出，使得流水断断续续，带宽仅有原来的1/2。
//而若fifo深度大于1，则fifo最终会平衡在一个非满非空的状态，此时可读可写，流水是连续的，可满带宽运行。
    fetch_fifo//带存储体的反压
    #(
        .OPC_INFO_W(2)
    )
    u_fifo
    (
        .clk_i                (clk_i                 ),
        .rstn_i               (rstn_i                ),
        .flush_i              (branch_request_i      ),
        .data_i               (fifo_instr_i          ),
        .data_vld_i           (fetch_in_valid_i      ),
        .data_rdy_o           (fetch_in_accept_o     ),
        .pc_data_i            (fetch_in_pc_i         ),
        .info0_in_i           ({fetch_in_fault_page_i,fetch_in_fault_fetch_i}),
        .info1_in_i           ({fetch_in_fault_page_i,fetch_in_fault_fetch_i}),
        .pred_in_i            (fetch_in_pred_branch_i),
             
        .data0_o              (fetch_out0_instr_o    ),
        .data0_vld_o          (fetch_out0_valid_o    ),   
        .data0_rdy_i          (fetch_out0_accept_i   ),
        .pc0_out_o            (fetch_out0_pc_o       ),
        .info0_out_o          ({fetch_out0_fault_page_o,fetch_out0_fault_fetch_o}),
        .data1_o              (fetch_out1_instr_o    ),
        .data1_vld_o          (fetch_out1_valid_o    ),   
        .data1_rdy_i          (fetch_out1_accept_i   ), 
        .pc1_out_o            (fetch_out1_pc_o       ), 
        .info1_out_o          ({fetch_out1_fault_page_o,fetch_out1_fault_fetch_o}) 
    );   
    decoder dec0  
    (
        .valid_i             (fetch_out0_valid_o            ),
        .fetch_fault_i       (fetch_out0_fault_page_o | fetch_out0_fault_fetch_o),
        .enable_muldiv_i     (enable_muldiv_w               ),
        .opcode_i            (fetch_out0_instr_o            ),

        .invalid_o           (fetch_out0_instr_invalid_o    ),
        .exec_o              (fetch_out0_instr_exec_o       ),
        .lsu_o               (fetch_out0_instr_lsu_o        ),
        .branch_o            (fetch_out0_instr_branch_o     ),
        .mul_o               (fetch_out0_instr_mul_o        ),
        .div_o               (fetch_out0_instr_div_o        ),
        .csr_o               (fetch_out0_instr_csr_o        ),
        .rs1_valid_o         (fetch_out0_instr_rs1_valid_o  ),
        .rs2_valid_o         (fetch_out0_instr_rs2_valid_o  ),
        .rd_valid_o          (fetch_out0_instr_rd_valid_o   ) 
    );

    decoder dec1  
    (
        .valid_i             (fetch_out1_valid_o            ),
        .fetch_fault_i       (fetch_out1_fault_page_o | fetch_out1_fault_fetch_o),
        .enable_muldiv_i     (enable_muldiv_w               ),
        .opcode_i            (fetch_out1_instr_o            ),

        .invalid_o           (fetch_out1_instr_invalid_o    ),
        .exec_o              (fetch_out1_instr_exec_o       ),
        .lsu_o               (fetch_out1_instr_lsu_o        ),
        .branch_o            (fetch_out1_instr_branch_o     ),
        .mul_o               (fetch_out1_instr_mul_o        ),
        .div_o               (fetch_out1_instr_div_o        ),
        .csr_o               (fetch_out1_instr_csr_o        ),
        .rs1_valid_o         (fetch_out1_instr_rs1_valid_o  ),
        .rs2_valid_o         (fetch_out1_instr_rs2_valid_o  ),
        .rd_valid_o          (fetch_out1_instr_rd_valid_o   )
    );
    end

endgenerate

endmodule

//单口输入双口输出同步FIFO
module fetch_fifo
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
    parameter WIDTH      = 64,
    parameter DEPTH      = 2,
    parameter ADDR_W     = 1,
    parameter OPC_INFO_W = 10
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    input  wire                     clk_i       ,
    input  wire                     rstn_i      ,
    input  wire                     flush_i     ,
    //write port
    input  wire [WIDTH-1:0]         data_i      ,
    input  wire                     data_vld_i  ,
    output wire                     data_rdy_o  ,
    input  wire [31:0]              pc_data_i   ,
    input  wire [OPC_INFO_W-1:0]    info0_in_i  ,//转发信息
    input  wire [OPC_INFO_W-1:0]    info1_in_i  ,
    input  wire [1:0]               pred_in_i   ,//分支预测信息？
    //read port0 
    output wire [(WIDTH/2)-1:0]     data0_o     ,
    output wire                     data0_vld_o ,   
    input  wire                     data0_rdy_i ,
    output wire [31:0]              pc0_out_o   ,
    output wire [OPC_INFO_W-1:0]    info0_out_o ,
    //read port1
    output wire [(WIDTH/2)-1:0]     data1_o     ,
    output wire                     data1_vld_o ,   
    input  wire                     data1_rdy_i , 
    output wire [31:0]              pc1_out_o   , 
    output wire [OPC_INFO_W-1:0]    info1_out_o  
);

    localparam COUNT_W = ADDR_W + 1;

    reg [31:0]           pc_q[DEPTH-1:0];
    reg                  valid0_q[DEPTH-1:0];
    reg                  valid1_q[DEPTH-1:0];
    reg [OPC_INFO_W-1:0] info0_q[DEPTH-1:0];
    reg [OPC_INFO_W-1:0] info1_q[DEPTH-1:0];
    reg [WIDTH-1:0]      ram_q[DEPTH-1:0];
    reg [ADDR_W-1:0]     rd_ptr_q;//读指针
    reg [ADDR_W-1:0]     wr_ptr_q;//写指针
    reg [COUNT_W-1:0]    count_q;//有效数据位计数器

    wire wr_en       = data_vld_i  & data_rdy_o;
    wire rd0_en      = data0_rdy_i & data0_vld_o;
    wire rd1_en      = data1_rdy_i & data1_vld_o;
    wire rd_complete = (rd0_en && ~data1_vld_o) || (rd1_en && ~data0_vld_o) || (rd0_en && rd1_en);

    integer i;

    always @ (posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                ram_q[i]    <= {WIDTH{1'b0}};
                pc_q[i]     <= 32'b0;
                info0_q[i]  <= {OPC_INFO_W{1'b0}};
                info1_q[i]  <= {OPC_INFO_W{1'b0}};
            end
        end 
        else if (flush_i) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                info0_q[i]  <= {OPC_INFO_W{1'b0}};
                info1_q[i]  <= {OPC_INFO_W{1'b0}};
            end
        end 
        else begin
            if (wr_en) begin
                ram_q[wr_ptr_q]    <= data_i;
                pc_q[wr_ptr_q]     <= pc_data_i;
                info0_q[wr_ptr_q]  <= info0_in_i;
                info1_q[wr_ptr_q]  <= info1_in_i;
            end
        end
    end

    always @ (posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                valid0_q[i] <= 1'b0;
                valid1_q[i] <= 1'b0;
            end
        end else if (wr_en) begin
            valid0_q[wr_ptr_q] <= 1'b1;
            valid1_q[wr_ptr_q] <= ~pred_in_i[0];//根据低位指令跳转，第二条指令不取
        end else if (rd0_en) begin
                valid0_q[rd_ptr_q] <= 1'b0;//读完该位就无效
        end else if (rd1_en) begin
                valid1_q[rd_ptr_q] <= 1'b0;
        end
    end
//数据计数器
    always @ (posedge clk_i or negedge rstn_i) begin
        if (!rstn_i)
            count_q <= {COUNT_W{1'b0}};
        else if (flush_i) 
            count_q <= {COUNT_W{1'b0}};
        else begin
            if (wr_en & ~rd_complete)
                count_q <= count_q + 1;
            else if (~wr_en & rd_complete)
                count_q <= count_q - 1;
            else 
                count_q <= count_q;
        end
    end
//读写指针的更新
    always @ (posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            rd_ptr_q  <= {ADDR_W{1'b0}};
            wr_ptr_q  <= {ADDR_W{1'b0}};
        end 
        else if (flush_i) begin
            rd_ptr_q  <= {ADDR_W{1'b0}};
            wr_ptr_q  <= {ADDR_W{1'b0}};
        end 
        else begin
            if (wr_en)//写
                wr_ptr_q  <= wr_ptr_q + 1;
                
            if (rd_complete)//读
                rd_ptr_q  <= rd_ptr_q + 1;
        end
    end

    assign data_rdy_o  = (count_q != DEPTH);//fifo未满可写

    assign data0_o     = ram_q[rd_ptr_q][(WIDTH/2)-1:0];
    assign data1_o     = ram_q[rd_ptr_q][WIDTH-1:(WIDTH/2)];
    assign data0_vld_o = (count_q != 0) & valid0_q[rd_ptr_q];//fifo未空可读
    assign data1_vld_o = (count_q != 0) & valid1_q[rd_ptr_q];
    assign pc0_out_o   = {pc_q[rd_ptr_q][31:3],3'b000};
    assign pc1_out_o   = {pc_q[rd_ptr_q][31:3],3'b100};
    assign info0_out_o = info0_q[rd_ptr_q];
    assign info1_out_o = info1_q[rd_ptr_q];
   

endmodule