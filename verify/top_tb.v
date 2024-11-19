module top_tb();

reg clk_i;
reg rstn_i;
reg [600:0] inst_name;
reg [600:0] inst_list [0:50];
reg [7:0]   mem [131072:0];

integer i;
integer k;
wire [31:0] s10_x26  = u_top.u_core.u_issue.u_regfile.x26_s10_w;
wire [31:0] s11_x27  = u_top.u_core.u_issue.u_regfile.x27_s11_w;
wire [31:0] gp_x3  = u_top.u_core.u_issue.u_regfile.x3_gp_w;
wire [31:0] a7_x17 = u_top.u_core.u_issue.u_regfile.x17_a7_w;
wire [31:0] a0_x10 = u_top.u_core.u_issue.u_regfile.x10_a0_w;
initial begin  
    clk_i  = 1'b0;
    rstn_i = 1'b0;
    #20
    rstn_i = 1'b1;
    for (k = 0; k <= 45; k=k+1) begin
        inst_name = inst_list[k];
        inst_load(inst_name);
        #20;
    end 
    wait(a7_x17 == 32'h5d);
    #200
    $finish;
end

always #10 clk_i = ~clk_i;

task inst_load;
    input [600:0] inst_name;
    begin
    for (i=0;i<131072;i=i+1)
        mem[i] = 0;
    $readmemh(inst_name, mem);
    for (i=0;i<131072;i=i+1) begin
        u_top.u_rom.write(i, mem[i]);
        u_top.u_ram.write(i, mem[i]);
    end
    wait(a7_x17 == 32'h5d);
    
    #500;
    end
endtask

task reset;                // reset 1 clock
    begin
        rstn_i = 0; 
        #20;
        rstn_i = 1;
    end
endtask


initial begin
    for (i=0;i<131072;i=i+1)
        mem[i] = 0;
    $readmemh("../riscv-tests/isa/generated/rv32ui-p-bne.verilog", mem);//L\S\
    for (i=0;i<131072;i=i+1)
        u_top.u_rom.write(i, mem[i]);
    wait(s10_x26 == 32'b1);
    #1000
    $finish;
end


integer r;
always begin
    wait(a7_x17 == 32'h5d)   
        #100
        if (a0_x10 == 32'h0) begin
            $display("~~~~~~~~~~~~~~~~~~~ %s PASS ~~~~~~~~~~~~~~~~~~~",inst_name);
            reset;
        end 
        else begin
            $display("~~~~~~~~~~~~~~~~~~~ %s FAIL ~~~~~~~~~~~~~~~~~~~~",inst_name);
            $display("fail testnum = %2d", a0_x10);
            $finish;
            //for (r = 0; r < 32; r = r + 1)
            //    $display("x%2d = 0x%x", r, rv32i_min_sopc_inst0. rv32i_inst0. regfile_inst0.regs[r]);
        end
end

initial begin
    inst_list[0]  = "../riscv-tests/isa/generated/rv32ui-p-add.verilog";   inst_list[1]  = "../riscv-tests/isa/generated/rv32ui-p-sub.verilog";  inst_list[2]  = "../riscv-tests/isa/generated/rv32ui-p-xor.verilog";
    inst_list[3]  = "../riscv-tests/isa/generated/rv32ui-p-or.verilog";    inst_list[4]  = "../riscv-tests/isa/generated/rv32ui-p-and.verilog";  inst_list[5]  = "../riscv-tests/isa/generated/rv32ui-p-sll.verilog";
    inst_list[6]  = "../riscv-tests/isa/generated/rv32ui-p-srl.verilog";   inst_list[7]  = "../riscv-tests/isa/generated/rv32ui-p-sra.verilog";  inst_list[8]  = "../riscv-tests/isa/generated/rv32ui-p-slt.verilog";
    inst_list[9]  = "../riscv-tests/isa/generated/rv32ui-p-sltu.verilog";  inst_list[10] = "../riscv-tests/isa/generated/rv32ui-p-addi.verilog"; inst_list[11] = "../riscv-tests/isa/generated/rv32ui-p-xori.verilog";
    inst_list[12] = "../riscv-tests/isa/generated/rv32ui-p-ori.verilog";   inst_list[13] = "../riscv-tests/isa/generated/rv32ui-p-andi.verilog"; inst_list[14] = "../riscv-tests/isa/generated/rv32ui-p-slli.verilog";
    inst_list[15] = "../riscv-tests/isa/generated/rv32ui-p-srli.verilog";  inst_list[16] = "../riscv-tests/isa/generated/rv32ui-p-srai.verilog"; inst_list[17] = "../riscv-tests/isa/generated/rv32ui-p-slti.verilog";
    inst_list[18] = "../riscv-tests/isa/generated/rv32ui-p-sltiu.verilog"; inst_list[19] = "../riscv-tests/isa/generated/rv32ui-p-beq.verilog";  inst_list[20] = "../riscv-tests/isa/generated/rv32ui-p-bne.verilog";  
    inst_list[21] = "../riscv-tests/isa/generated/rv32ui-p-blt.verilog";   inst_list[22] = "../riscv-tests/isa/generated/rv32ui-p-bge.verilog";  inst_list[23] = "../riscv-tests/isa/generated/rv32ui-p-bltu.verilog"; 
    inst_list[24] = "../riscv-tests/isa/generated/rv32ui-p-bgeu.verilog";  inst_list[25] = "../riscv-tests/isa/generated/rv32ui-p-jal.verilog";  inst_list[26] = "../riscv-tests/isa/generated/rv32ui-p-jalr.verilog"; 
    inst_list[27] = "../riscv-tests/isa/generated/rv32ui-p-lui.verilog";   inst_list[28] = "../riscv-tests/isa/generated/rv32ui-p-auipc.verilog";inst_list[29] = "../riscv-tests/isa/generated/rv32ui-p-sb.verilog";   
    inst_list[30] = "../riscv-tests/isa/generated/rv32ui-p-sh.verilog";    inst_list[31] = "../riscv-tests/isa/generated/rv32ui-p-sw.verilog";   inst_list[32] = "../riscv-tests/isa/generated/rv32ui-p-lb.verilog";  
    inst_list[33] = "../riscv-tests/isa/generated/rv32ui-p-lh.verilog";    inst_list[34] = "../riscv-tests/isa/generated/rv32ui-p-lw.verilog";   inst_list[35] = "../riscv-tests/isa/generated/rv32ui-p-lbu.verilog";   
    inst_list[36] = "../riscv-tests/isa/generated/rv32ui-p-lhu.verilog";   inst_list[37] = "../riscv-tests/isa/generated/rv32um-p-mul.verilog";  inst_list[38] = "../riscv-tests/isa/generated/rv32um-p-mulh.verilog"; 
    inst_list[39] = "../riscv-tests/isa/generated/rv32um-p-mulhsu.verilog";inst_list[40] = "../riscv-tests/isa/generated/rv32um-p-mulhu.verilog";inst_list[41] = "../riscv-tests/isa/generated/rv32um-p-div.verilog";  
    inst_list[42] = "../riscv-tests/isa/generated/rv32um-p-divu.verilog";  inst_list[43] = "../riscv-tests/isa/generated/rv32um-p-rem.verilog";  inst_list[44] = "../riscv-tests/isa/generated/rv32um-p-remu.verilog";
    inst_list[45] = "../riscv-tests/isa/generated/rv32ui-v-add.verilog";
end

initial begin
    #(30 * 50000);
    $display("Time Out");
    $finish;
end

wire          mem_i_rd_w;
wire          mem_i_flush_w;
wire          mem_i_invalidate_w;
wire [ 31:0]  mem_i_pc_w;
wire [ 31:0]  mem_d_addr_w;
wire [ 31:0]  mem_d_data_wr_w;
wire          mem_d_rd_w;
wire [  3:0]  mem_d_wr_w;
wire          mem_d_cacheable_w;
wire [ 10:0]  mem_d_req_tag_w;
wire          mem_d_invalidate_w;
wire          mem_d_writeback_w;
wire          mem_d_flush_w;
wire          mem_i_accept_w;
wire          mem_i_valid_w;
wire          mem_i_error_w;
wire [ 63:0]  mem_i_inst_w;
wire [ 31:0]  mem_d_data_rd_w;
wire          mem_d_accept_w;
wire          mem_d_ack_w;
wire          mem_d_error_w;
wire [ 10:0]  mem_d_resp_tag_w;

top u_top
(
    .clk_i             (clk_i ),
    .rstn_i            (rstn_i) 
);



initial begin
    $fsdbDumpfile("top.fsdb");
    $fsdbDumpvars(0);
    $fsdbDumpMDA();
end


endmodule
