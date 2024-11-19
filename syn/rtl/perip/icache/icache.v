//阻塞型Cache，lookup发生miss时，等待refill，完成后再次lookup
module icache
#(
     parameter AXI_ID           = 0
)
(
    input   wire          clk_i             ,
    input   wire          rstn_i            ,

    input   wire          req_rd_i          ,
    input   wire          req_flush_i       ,
    input   wire          req_invalidate_i  ,
    input   wire [31:0]   req_pc_i          ,
    output  wire          req_accept_o      ,
    output  wire          req_valid_o       ,
    output  wire          req_error_o       ,
    output  wire [63:0]   req_inst_o        ,
//axi interface
    //read address channel
    output  wire          axi_arvalid_o     ,
    output  wire [31:0]   axi_araddr_o      ,
    output  wire [ 3:0]   axi_arid_o        ,
    output  wire [ 7:0]   axi_arlen_o       ,
    output  wire [ 1:0]   axi_arburst_o     ,
    input   wire          axi_arready_i     ,
    //read data channel  
    input   wire [31:0]   axi_rdata_i       ,
    input   wire [ 1:0]   axi_rresp_i       ,
    input   wire [ 3:0]   axi_rid_i         ,
    input   wire          axi_rlast_i       ,//用于标记突发传输的最后一个cycle
    input   wire          axi_rvalid_i      ,      
    output  wire          axi_rready_o
);



//-----------------------------------------------------------------
// This cache instance is 2 way set associative.
// The total size is 16KB. 16x256 word   
// The replacement policy is a limited pseudo random scheme
// (between lines, toggling on line thrashing).
//-----------------------------------------------------------------
            //tag0                          //tag1
/*  ---------
    |        |word0|word1|                   |word0|word1|----------------
cache line   |word2|word3|                   |word2|word3|
    |        |word4|word5|                   |word4|word5|              |
    |        |word6|word7|                   |word6|word7|              |
    ------------                                                        |
            ..............                    ...........             x256    data_ram=4x256=1024
            ..............                    ...........               |
            ..............                    ...........               |
            ..............                    ...........               |
             |word |word |                    word |word |----------------    */
localparam ICACHE_NUM_WAYS           = 2;

localparam ICACHE_NUM_LINES          = 256;
localparam ICACHE_LINE_ADDR_W        = 8;
localparam ICACHE_LINE_WORDS         = 8;

localparam ICACHE_DATA_W             = 64;//一个data cache数据位宽
/*  31          16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00
   |--------------|  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
    +--------------------+  +--------------------+   +------------+
    |  Tag address.      |  |   Line address     |      Address 
    |                    |  |                    |      within line
    |                    |  |                    |
    |                    |  |                    |- ICACHE_TAG_REQ_LINE_L
    |                    |  |- ICACHE_TAG_REQ_LINE_H
    |                    |- ICACHE_TAG_CMP_ADDR_L
    |- ICACHE_TAG_CMP_ADDR_H                                              */
localparam ICACHE_LINE_SIZE_W        = 5; //用5个bit来寻地对应的32byte
localparam ICACHE_LINE_SIZE          = 32;//一个条cache line有32x8bit=32byte

localparam ICACHE_TAG_REQ_LINE_L     = 5; //寻址对应byte用了4：0位
localparam ICACHE_TAG_REQ_LINE_H     = 12;//ICACHE_LINE_ADDR_W+ICACHE_LINE_SIZE_W-1
localparam ICACHE_TAG_REQ_LINE_W     = 8; //寻址256个cache line
`define    ICACHE_TAG_REQ_RNG        ICACHE_TAG_REQ_LINE_H:ICACHE_TAG_REQ_LINE_L

localparam ICACHE_TAG_CMP_ADDR_L     = ICACHE_TAG_REQ_LINE_H + 1;
localparam ICACHE_TAG_CMP_ADDR_H     = 32-1;
localparam ICACHE_TAG_CMP_ADDR_W     = ICACHE_TAG_CMP_ADDR_H - ICACHE_TAG_CMP_ADDR_L + 1;
`define    ICACHE_TAG_CMP_ADDR_RNG   ICACHE_TAG_CMP_ADDR_H:ICACHE_TAG_CMP_ADDR_L

// Tag ram的数据位宽 19bit tag + 1bit valid bit = 20bit
`define    CACHE_TAG_ADDR_RNG          18:0
localparam CACHE_TAG_ADDR_BITS       = 19;
localparam CACHE_TAG_VALID_BIT       = CACHE_TAG_ADDR_BITS;
localparam CACHE_TAG_DATA_W          = CACHE_TAG_VALID_BIT + 1;

//寻址cache line的地址(Index)
wire [ICACHE_TAG_REQ_LINE_W-1:0] req_line_addr_w  = req_pc_i[`ICACHE_TAG_REQ_RNG];

//寻址data ram每个64BIT的地址
localparam CACHE_DATA_ADDR_W = ICACHE_LINE_ADDR_W+ICACHE_LINE_SIZE_W-3;
wire [CACHE_DATA_ADDR_W-1:0] req_data_addr_w = req_pc_i[CACHE_DATA_ADDR_W+3-1:3];//pc+8 

//-----------------------------------------------------------------
// States
//-----------------------------------------------------------------
localparam STATE_W           = 2;
localparam STATE_FLUSH       = 2'd0;
localparam STATE_LOOKUP      = 2'd1;
localparam STATE_REFILL      = 2'd2;//cache替换
localparam STATE_RELOOKUP    = 2'd3;

reg [STATE_W-1:0] next_state_r;
reg [STATE_W-1:0] state_q;

reg        invalidate_q;

reg [0:0]  replace_way_q;
//cache流水第一级寄存器(和读写ram一样延迟一个周期)
//lookup有效信号以及地址
reg lookup_valid_q;

always @ (posedge clk_i or negedge rstn_i) begin
    if (!rstn_i)
        lookup_valid_q <= 1'b0;
    else if (req_rd_i && req_accept_o)//访问cache握手
        lookup_valid_q <= 1'b1;
    else if (req_valid_o)//输出指令有效
        lookup_valid_q <= 1'b0;
end
reg [31:0] lookup_addr_q;

always @ (posedge clk_i or negedge rstn_i) begin
    if (!rstn_i)
        lookup_addr_q <= 32'b0;
    else if (req_rd_i && req_accept_o)//访问cache握手
        lookup_addr_q <= req_pc_i;
end

wire [ICACHE_TAG_CMP_ADDR_W-1:0] req_pc_tag_cmp_w = lookup_addr_q[`ICACHE_TAG_CMP_ADDR_RNG];//寻址到对应cacheline后用于对比的Tag

//-----------------------------------------------------------------
// TAG RAMS 在icache hit的情况下，只需要读icache，只要addr。miss时才需要从外部存储器读，需要addr,data,write_en
//-----------------------------------------------------------------
reg [ICACHE_TAG_REQ_LINE_W-1:0] tag_addr_r;//cacheline地址
reg [ICACHE_TAG_REQ_LINE_W-1:0] flush_addr_q;//需要冲刷的cacheline地址

// Tag RAM address
always @(*) begin
    tag_addr_r = flush_addr_q;
    // Cache flush
    if (state_q == STATE_FLUSH)
        tag_addr_r = flush_addr_q;
    // Line refill
    else if (state_q == STATE_REFILL || state_q == STATE_RELOOKUP)
        tag_addr_r = lookup_addr_q[`ICACHE_TAG_REQ_RNG];//延迟了一个cycle
    // Lookup
    else
        tag_addr_r = req_line_addr_w;//直接查找
end
// Tag RAM write data
reg [CACHE_TAG_DATA_W-1:0] tag_data_in_r;
always @(*) begin
    tag_data_in_r = {(CACHE_TAG_DATA_W){1'b0}};
    // Cache flush
    if (state_q == STATE_FLUSH)
        tag_data_in_r = {(CACHE_TAG_DATA_W){1'b0}};
    // Line refill
    else if (state_q == STATE_REFILL) begin
        tag_data_in_r[CACHE_TAG_VALID_BIT] = 1'b1;//有效位置1
        tag_data_in_r[`CACHE_TAG_ADDR_RNG] = lookup_addr_q[`ICACHE_TAG_CMP_ADDR_RNG];//写入新tag
    end
end
// Tag RAM write enable (way 0)
reg tag0_write_r;
always @(*) begin
    tag0_write_r = 1'b0;
    // Cache flush
    if (state_q == STATE_FLUSH)
        tag0_write_r = 1'b1;
    // Line refill
    else if (state_q == STATE_REFILL)
        tag0_write_r = (replace_way_q == 0) && axi_rvalid_i && axi_rlast_i;//从AXI总线读的数据准备好
end

wire [CACHE_TAG_DATA_W-1:0] tag0_data_out_w;
//读写花费一个cycle
icache_tag_ram u_tag0
(
  .clk_i        (clk_i          ),
  .addr_i       (tag_addr_r     ),
  .data_i       (tag_data_in_r  ),
  .wr_i         (tag0_write_r   ),
  .data_o       (tag0_data_out_w)
);
//读tag ram
wire tag0_valid_w = tag0_data_out_w[CACHE_TAG_VALID_BIT];
wire [CACHE_TAG_ADDR_BITS-1:0] tag0_addr_bits_w = tag0_data_out_w[`CACHE_TAG_ADDR_RNG];

//对比tag内容判断hit/miss
wire tag0_hit_w = tag0_valid_w ? (tag0_addr_bits_w == req_pc_tag_cmp_w) : 1'b0;

// Tag RAM write enable (way 1)
reg tag1_write_r;
always @(*) begin
    tag1_write_r = 1'b0;
    // Cache flush
    if (state_q == STATE_FLUSH)
        tag1_write_r = 1'b1;
    // Line refill
    else if (state_q == STATE_REFILL)
        tag1_write_r = (replace_way_q == 1) && axi_rvalid_i && axi_rlast_i;
end

wire [CACHE_TAG_DATA_W-1:0] tag1_data_out_w;

icache_tag_ram u_tag1
(
  .clk_i        (clk_i          ),
  .addr_i       (tag_addr_r     ),
  .data_i       (tag_data_in_r  ),
  .wr_i         (tag1_write_r   ),
  .data_o       (tag1_data_out_w)
);

wire tag1_valid_w = tag1_data_out_w[CACHE_TAG_VALID_BIT];
wire [CACHE_TAG_ADDR_BITS-1:0] tag1_addr_bits_w = tag1_data_out_w[`CACHE_TAG_ADDR_RNG];

wire tag1_hit_w = tag1_valid_w ? (tag1_addr_bits_w == req_pc_tag_cmp_w) : 1'b0;
//检查2个way是否有hit
wire tag_hit_any_w = 1'b0 | tag0_hit_w | tag1_hit_w;

//-----------------------------------------------------------------
// DATA RAMS
//-----------------------------------------------------------------
reg [CACHE_DATA_ADDR_W-1:0] data_addr_r;
reg [CACHE_DATA_ADDR_W-1:0] data_write_addr_q;
reg [2:0]  refill_word_idx_q;
reg [31:0] refill_lower_q;

always @ (posedge clk_i or negedge rstn_i) begin
    if (!rstn_i)
        refill_word_idx_q <= 3'b0;
    else if (axi_rvalid_i && axi_rlast_i)//一共传输8个word
        refill_word_idx_q <= 3'b0;
    else if (axi_rvalid_i)
        refill_word_idx_q <= refill_word_idx_q + 3'd1;
end

always @ (posedge clk_i or negedge rstn_i) begin
    if (!rstn_i)
        refill_lower_q <= 32'b0;
    else if (axi_rvalid_i)
        refill_lower_q <= axi_rdata_i;//SRAM一次写64bit，把上个周期的32bit进行拼接
end

// Data RAM refill write address
always @ (posedge clk_i or negedge rstn_i) begin
    if (!rstn_i)
        data_write_addr_q <= {(CACHE_DATA_ADDR_W){1'b0}};
    else if (state_q == STATE_LOOKUP && next_state_r == STATE_REFILL)
        data_write_addr_q <= axi_araddr_o[CACHE_DATA_ADDR_W+3-1:3];//要写的cacheline地址
    else if (state_q == STATE_REFILL && axi_rvalid_i && refill_word_idx_q[0])//写的时候对齐64bit边界
        data_write_addr_q <= data_write_addr_q + 1;
end
// Data RAM address
always @(*) begin
    data_addr_r = req_data_addr_w;
    // Line refill
    if (state_q == STATE_REFILL)
        data_addr_r = data_write_addr_q;
    // Lookup after refill
    else if (state_q == STATE_RELOOKUP)
        data_addr_r = lookup_addr_q[CACHE_DATA_ADDR_W+3-1:3];
    // Lookup
    else
        data_addr_r = req_data_addr_w;
end

// Data RAM write enable (way 0)
reg data0_write_r;
always @(*) begin
    data0_write_r = axi_rvalid_i && replace_way_q == 0;
end

wire [ICACHE_DATA_W-1:0] data0_data_out_w;

icache_data_ram
u_data0
(
  .clk_i    (clk_i           ),
  .addr_i   (data_addr_r     ),
  .data_i   ({axi_rdata_i,refill_lower_q}),
  .wr_i     (data0_write_r   ),
  .data_o   (data0_data_out_w)
);

// Data RAM write enable (way 1)
reg data1_write_r;
always @(*) begin
    data1_write_r = axi_rvalid_i && replace_way_q == 1;
end

wire [ICACHE_DATA_W-1:0] data1_data_out_w;

icache_data_ram
u_data1
(
  .clk_i    (clk_i           ),
  .addr_i   (data_addr_r     ),
  .data_i   ({axi_rdata_i,refill_lower_q}),
  .wr_i     (data1_write_r   ),
  .data_o   (data1_data_out_w)
);

//-----------------------------------------------------------------
// Flush counter
//-----------------------------------------------------------------
always @ (posedge clk_i or negedge rstn_i) begin
    if (!rstn_i)
        flush_addr_q <= {(ICACHE_TAG_REQ_LINE_W){1'b0}};
    else if (state_q == STATE_FLUSH)
        flush_addr_q <= flush_addr_q + 1;
    // Invalidate specified line
    else if (req_invalidate_i && req_accept_o)
        flush_addr_q <= req_line_addr_w;
    else
        flush_addr_q <= {(ICACHE_TAG_REQ_LINE_W){1'b0}};
end
//-----------------------------------------------------------------
// Replacement Policy
//--------------------------------------------------------------- 
// Using random replacement policy - this way we cycle through the ways
// when needing to replace a line.
always @ (posedge clk_i or negedge rstn_i)
if (!rstn_i)
    replace_way_q <= 0;
else if (axi_rvalid_i && axi_rlast_i)
    replace_way_q <= replace_way_q + 1;

//-----------------------------------------------------------------
// Instruction Output
//-----------------------------------------------------------------
assign req_valid_o = lookup_valid_q && ((state_q == STATE_LOOKUP) ? tag_hit_any_w : 1'b0);

// Data output mux
reg [ICACHE_DATA_W-1:0] inst_r;
always @(*) begin
    inst_r = 64'b0;
    case (1'b1)
    tag0_hit_w: inst_r = data0_data_out_w;
    tag1_hit_w: inst_r = data1_data_out_w;
    endcase
end

assign req_inst_o    = inst_r;

//-----------------------------------------------------------------
// Next State Logic
//-----------------------------------------------------------------
always @(*) begin
    next_state_r = state_q;
    case (state_q)
    STATE_FLUSH: begin
        if (invalidate_q)
            next_state_r = STATE_LOOKUP;
        else if (flush_addr_q == {(ICACHE_TAG_REQ_LINE_W){1'b1}})
            next_state_r = STATE_LOOKUP;
    end
    STATE_LOOKUP : begin
        // Tried a lookup but no match found
        if (lookup_valid_q && !tag_hit_any_w)
            next_state_r = STATE_REFILL;
        // Invalidate a line / flush cache
        else if (req_invalidate_i || req_flush_i)//暂时不用，req_invalidate_i=0，req_flush_i和ifence有关
            next_state_r = STATE_FLUSH;
    end
    STATE_REFILL : begin
        // End of refill
        if (axi_rvalid_i && axi_rlast_i)
            next_state_r = STATE_RELOOKUP;
    end
    // STATE_RELOOKUP 用于满足时序的过渡状态？？
    STATE_RELOOKUP : begin
        next_state_r = STATE_LOOKUP;
    end
    default:
        ;
   endcase
end

// Update state
always @ (posedge clk_i or negedge rstn_i) begin
    if (!rstn_i)
        state_q   <= STATE_FLUSH;
    else
        state_q   <= next_state_r;
end

assign req_accept_o = (state_q == STATE_LOOKUP && next_state_r != STATE_REFILL);

//-----------------------------------------------------------------
// Invalidate  暂时不用
//-----------------------------------------------------------------
always @ (posedge clk_i or negedge rstn_i)
if (!rstn_i)
    invalidate_q   <= 1'b0;
else if (req_invalidate_i && req_accept_o)
    invalidate_q   <= 1'b1;
else
    invalidate_q   <= 1'b0;

//-----------------------------------------------------------------
// AXI Request Hold
//-----------------------------------------------------------------
reg axi_arvalid_q;
always @ (posedge clk_i or negedge rstn_i)
if (!rstn_i)
    axi_arvalid_q   <= 1'b0;
else if (axi_arvalid_o && !axi_arready_i)
    axi_arvalid_q   <= 1'b1;
else
    axi_arvalid_q   <= 1'b0;

//------------------------    //----------------------------------------------------------------------------------
// AXI Error Handling
//-----------------------------------------------------------------
reg axi_error_q;
always @ (posedge clk_i or negedge rstn_i) begin
    if (!rstn_i)
        axi_error_q   <= 1'b0;
    else if (axi_rvalid_i && axi_rready_o && axi_rresp_i != 2'b0)
        axi_error_q   <= 1'b1;
    else if (req_valid_o)
        axi_error_q   <= 1'b0;
end

assign req_error_o = axi_error_q;

//-----------------------------------------------------------------
// AXI
//-----------------------------------------------------------------

// AXI Read channel
assign axi_arvalid_o = (state_q == STATE_LOOKUP && next_state_r == STATE_REFILL) || axi_arvalid_q;
assign axi_araddr_o  = {lookup_addr_q[31:ICACHE_LINE_SIZE_W], {(ICACHE_LINE_SIZE_W){1'b0}}};
assign axi_arburst_o = 2'd1; // INCR
assign axi_arid_o    = AXI_ID;
assign axi_arlen_o   = 8'd7;
assign axi_rready_o  = 1'b1;



endmodule
