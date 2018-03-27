/* Dev Sharma - dsharma */
/* Jamaal Hay - jamaalh */

`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk,                // main clock
    input wire         rst, // global reset
    input wire         gwe, // global we for single-step clock
                                    
    output wire [15:0] o_cur_pc, // Address to read from instruction memory
    input wire [15:0]  i_cur_insn, // Output of instruction memory
    output wire [15:0] o_dmem_addr, // Address to read/write from/to data memory
    input wire [15:0]  i_cur_dmem_data, // Output of data memory
    output wire        o_dmem_we, // Data memory write enable
    output wire [15:0] o_dmem_towrite, // Value to write to data memory
   
    output wire [1:0]  test_stall, // Testbench: is this is stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc, // Testbench: program counter
    output wire [15:0] test_cur_insn, // Testbench: instruction bits
    output wire        test_regfile_we, // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel, // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data, // Testbench: value to write into the register file
    output wire        test_nzp_we, // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits, // Testbench: value to write to NZP bits
    output wire        test_dmem_we, // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr, // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data, // Testbench: value read/writen from/to memory

    input wire [7:0]   switch_data, // Current settings of the Zedboard switches
    output wire [7:0]  led_data // Which Zedboard LEDs should be turned on?
    );
   
   /*** YOUR CODE HERE ***/

   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    * 
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    */
    
    wire is_stall; //detects load to use dependencies then stalls pipeline (disable we's in F-stage, insert NOP in D-stage)
    wire is_flush; //detects branch misprediction and inserts NOP's into F and D stages
    
    
/**********************************************FETCH STAGE**********************************************/

    wire [15:0] F_pc;      // Current program counter (read out from pc_reg)
    assign o_cur_pc = F_pc; //read current PC from PC_reg
    
    wire [1:0] F_stall = is_flush ? 2'h2 : 2'b0; //set test_stall signal to indicate flush due to branch
    wire [15:0] F_insn = is_flush ? 16'h0 : i_cur_insn; //inject NOP on branch misprediction
    wire [15:0] F_next_pc = is_flush ? X_alu_result : F_pc+16'b1; //mux between PC+1 and branch target
    
    wire F_we = ~is_stall; //disable we of all registers in F-stage when stalling

    // Program counter register, starts at 8200h at bootup
    Nbit_reg #(16, 16'h8200) pc_reg (.in(F_next_pc), .out(F_pc), .clk(clk), .we(F_we), .gwe(gwe), .rst(rst));

/****Fetch-Decode Intermediate Register****/

    //FD_reg output wires
    wire [15:0] D_IR_pc;
    wire [15:0] D_IR_insn;
    wire [1:0] D_IR_stall;
    //FD_reg registers
    Nbit_reg #(16, 16'h0) FD_pc (.in(F_pc), .out(D_IR_pc), .clk(clk), .we(F_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) FD_insn (.in(F_insn), .out(D_IR_insn), .clk(clk), .we(F_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'h2) FD_stall (.in(F_stall), .out(D_IR_stall), .clk(clk), .we(F_we), .gwe(gwe), .rst(rst));
    
/**********************************************DECODE STAGE**********************************************/

/****Stall Logic****/
    wire [2:0] D_stall_r1;
    wire [2:0] D_stall_r2;
    wire D_stall_r1re;
    wire D_stall_r2re;
    wire D_stall_is_store;
    wire D_stall_is_branch;
    //Use parallel decoder to detect stalls because other decoder will be flushed with NOP when a stall is needed. Can't decode stall logic and flush the same decoder in 1 cycle
    lc4_decoder stall_decoder(.insn(D_IR_insn), .r1sel(D_stall_r1), .r1re(D_stall_r1re), .r2sel(D_stall_r2), .r2re(D_stall_r2re), .wsel(), .regfile_we(), .nzp_we(), .select_pc_plus_one(),
                            .is_load(), .is_store(D_stall_is_store), .is_branch(D_stall_is_branch), .is_control_insn());
    
    //assign stall for load-to-use dependencies, includes load-to-branch, excludes load to store where loaded data is stored
    assign is_stall = X_IR_is_load & (((D_stall_r1 == X_IR_rd) & D_stall_r1re) || ((D_stall_r2 == X_IR_rd) & D_stall_r2re & ~D_stall_is_store) || D_stall_is_branch);
    
    //decoder output wires
    wire [2:0] D_r1;
    wire [2:0] D_r2;
    wire [2:0] D_rd;
    wire D_r1re;
    wire D_r2re;
    wire D_select_pc_plus_one;
    wire D_is_load;
    wire D_is_store;
    wire D_is_branch;
    wire D_is_control_insn;
    wire D_regfile_we;
    wire D_nzp_we;
    
    wire [15:0] D_insn = (is_stall | is_flush) ? 16'h0 : D_IR_insn; //CHANGE TO SUPPORT BRANCH/STALL
    
    wire [1:0] D_stall = is_stall ? 2'h3 : is_flush ? 2'h2 : D_IR_stall; //CHNAGE TO SUPPORT BRANCH/STALL
    
    //decoder
    lc4_decoder decoder(.insn(D_insn), .r1sel(D_r1), .r1re(D_r1re), .r2sel(D_r2), .r2re(D_r2re), .wsel(D_rd), .regfile_we(D_regfile_we), .nzp_we(D_nzp_we), .select_pc_plus_one(D_select_pc_plus_one),
                            .is_load(D_is_load), .is_store(D_is_store), .is_branch(D_is_branch), .is_control_insn(D_is_control_insn));
    
    //regfile output wires
    wire [15:0] D_regfile_r1_data;
    wire [15:0] D_regfile_r2_data;
    //WD Bypass
    wire [15:0] D_r1_data = (D_r1 == W_IR_rd) & W_IR_regfile_we ? W_rd_data : D_regfile_r1_data;
    wire [15:0] D_r2_data = (D_r2 == W_IR_rd) & W_IR_regfile_we ? W_rd_data : D_regfile_r2_data;
    
    
    //regfile
    lc4_regfile regfile(.i_rd(W_IR_rd), .i_rs(D_r1), .i_rt(D_r2), .i_rd_we(W_IR_regfile_we), .i_wdata(W_rd_data), .o_rs_data(D_regfile_r1_data), .o_rt_data(D_regfile_r2_data), .clk(clk) , .gwe(gwe), .rst(rst));
    
/****Decode-Execute Intermediate Register****/

    //DX_reg output wires
    wire [15:0] X_IR_r1_data;
    wire [15:0] X_IR_r2_data;
    wire [2:0] X_IR_r1;
    wire [2:0] X_IR_r2;
    wire [2:0] X_IR_rd;
    wire X_IR_r1re;
    wire X_IR_r2re;
    wire X_IR_select_pc_plus_one;
    wire X_IR_is_load;
    wire X_IR_is_store;
    wire X_IR_is_branch;
    wire X_IR_is_control_insn;
    wire X_IR_regfile_we;
    wire X_IR_nzp_we;
    wire [1:0] X_IR_stall;
    //End new outputs
    wire [15:0] X_IR_pc;
    wire [15:0] X_IR_insn;
    
    //DX_reg registers
    Nbit_reg #(16, 16'h0) DX_r1_data (.in(D_r1_data), .out(X_IR_r1_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) DX_r2_data (.in(D_r2_data), .out(X_IR_r2_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) DX_r1 (.in(D_r1), .out(X_IR_r1), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) DX_r2 (.in(D_r2), .out(X_IR_r2), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) DX_rd (.in(D_rd), .out(X_IR_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_r1re (.in(D_r1re), .out(X_IR_r1re), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_r2re (.in(D_r2re), .out(X_IR_r2re), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_select_pc_plus_one (.in(D_select_pc_plus_one), .out(X_IR_select_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_is_load (.in(D_is_load), .out(X_IR_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_is_store (.in(D_is_store), .out(X_IR_is_store), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_is_branch (.in(D_is_branch), .out(X_IR_is_branch), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_is_control_insn (.in(D_is_control_insn), .out(X_IR_is_control_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_regfile_we (.in(D_regfile_we), .out(X_IR_regfile_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_nzp_we (.in(D_nzp_we), .out(X_IR_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    //End new registers
    Nbit_reg #(16, 16'h0) DX_pc (.in(D_IR_pc), .out(X_IR_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) DX_insn (.in(D_insn), .out(X_IR_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'h2) DX_stall (.in(D_stall), .out(X_IR_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
/**********************************************EXECUTE STAGE**********************************************/

    //WX and MX Bypassing
    wire [15:0] X_r1_data = (M_IR_rd == X_IR_r1) & M_IR_regfile_we ? M_IR_rd_data : (W_IR_rd == X_IR_r1) & W_IR_regfile_we ? W_rd_data : X_IR_r1_data;
    wire [15:0] X_r2_data = (M_IR_rd == X_IR_r2) & M_IR_regfile_we ? M_IR_rd_data : (W_IR_rd == X_IR_r2) & W_IR_regfile_we ? W_rd_data : X_IR_r2_data;
    
    //alu
    wire [15:0] X_alu_result;
    lc4_alu alu(.i_insn(X_IR_insn), .i_pc(X_IR_pc), .i_r1data(X_r1_data), .i_r2data(X_r2_data), .o_result(X_alu_result));
    wire [15:0] X_rd_data = X_IR_select_pc_plus_one ? (X_IR_pc+16'b1) : X_alu_result;
    
/****NZP/Branch Logic****/
    //WX and MX bypass for NZP bits
    wire [15:0] X_nzp_in = M_IR_nzp_we ? M_IR_rd_data : W_rd_data;
    wire [2:0] X_nzp_new_bits = X_nzp_in[15] ? 3'h4 : (X_nzp_in == 16'h0) ? 3'h2 : 3'h1;
    wire [2:0] X_nzp_bits = (M_IR_nzp_we | W_IR_nzp_we) ? X_nzp_new_bits : X_nzp_reg_out;
    //NZP register
    wire [2:0] X_nzp_reg_out;
    Nbit_reg #(3, 3'b000) NZP_reg (.in(X_nzp_new_bits), .out(X_nzp_reg_out), .clk(clk), .we(W_IR_nzp_we), .gwe(gwe), .rst(rst));
    //Branch Logic
    wire [2:0] X_nzp_se = X_IR_insn[11:9];
    wire X_p = X_nzp_bits[0];
    wire X_z = X_nzp_bits[1];
    wire X_n = X_nzp_bits[2];
    wire X_br_e =   X_nzp_se == 3'h0 ? 1'b0 :
                    X_nzp_se == 3'h1 ? X_p :
                    X_nzp_se == 3'h2 ? X_z :
                    X_nzp_se == 3'h3 ? X_z | X_p :
                    X_nzp_se == 3'h4 ? X_n :
                    X_nzp_se == 3'h5 ? X_n | X_p :
                    X_nzp_se == 3'h6 ? X_n | X_z :
                    X_n | X_z | X_p ;
    
    assign is_flush = (X_br_e & X_IR_is_branch) | X_IR_is_control_insn; //set flush for taken branches
                    
    
/****Execute-Memory Intermediate Register****/

    //XM_reg output wires
    wire [15:0] M_IR_alu_result;
    wire [15:0] M_IR_rd_data;
    //End new outputs
    wire [15:0] M_IR_r1_data;
    wire [15:0] M_IR_r2_data;
    wire [2:0] M_IR_r1;
    wire [2:0] M_IR_r2;
    wire [2:0] M_IR_rd;
    wire M_IR_r1re;
    wire M_IR_r2re;
    wire M_IR_select_pc_plus_one;
    wire M_IR_is_load;
    wire M_IR_is_store;
    wire M_IR_is_branch;
    wire M_IR_is_control_insn;
    wire M_IR_regfile_we;
    wire M_IR_nzp_we;
    wire [15:0] M_IR_pc;
    wire [15:0] M_IR_insn;
    wire [1:0] M_IR_stall;
    
    //XM_reg registers
    Nbit_reg #(16, 16'h0) XM_alu_result (.in(X_alu_result), .out(M_IR_alu_result), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) XM_rd_data (.in(X_rd_data), .out(M_IR_rd_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    //End new registers
    Nbit_reg #(16, 16'h0) XM_r1_data (.in(X_r1_data), .out(M_IR_r1_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //NOT COPIED - changes in X-stage
    Nbit_reg #(16, 16'h0) XM_r2_data (.in(X_r2_data), .out(M_IR_r2_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //NOT COPIED - changes in X-stage
    Nbit_reg #(3, 3'h0) XM_r1 (.in(X_IR_r1), .out(M_IR_r1), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) XM_r2 (.in(X_IR_r2), .out(M_IR_r2), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) XM_rd (.in(X_IR_rd), .out(M_IR_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_r1re (.in(X_IR_r1re), .out(M_IR_r1re), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_r2re (.in(X_IR_r2re), .out(M_IR_r2re), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_select_pc_plus_one (.in(X_IR_select_pc_plus_one), .out(M_IR_select_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_is_load (.in(X_IR_is_load), .out(M_IR_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_is_store (.in(X_IR_is_store), .out(M_IR_is_store), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_is_branch (.in(X_IR_is_branch), .out(M_IR_is_branch), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_is_control_insn (.in(X_IR_is_control_insn), .out(M_IR_is_control_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_regfile_we (.in(X_IR_regfile_we), .out(M_IR_regfile_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_nzp_we (.in(X_IR_nzp_we), .out(M_IR_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) XM_pc (.in(X_IR_pc), .out(M_IR_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) XM_insn (.in(X_IR_insn), .out(M_IR_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'h2) XM_stall (.in(X_IR_stall), .out(M_IR_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    
/**********************************************MEMORY STAGE**********************************************/
    
    wire [15:0] M_dmem_addr = (M_IR_is_load | M_IR_is_store) ? M_IR_alu_result : 16'h0; //memory address
    wire [15:0] M_r2_data = (M_IR_r2 == W_IR_rd) & W_IR_regfile_we ? W_rd_data : M_IR_r2_data; //WM Bypass - assign memory write data
    
    wire [15:0] M_dmem_data = i_cur_dmem_data; //read current output of memory
    
    //assign inputs to memory 
    assign o_dmem_towrite = M_r2_data;
    assign o_dmem_we = M_IR_is_store;
    assign o_dmem_addr = M_dmem_addr;
    
/****Memory-Writeback Intermediate Register***/

    //WM_reg output wires
    wire [15:0] W_IR_dmem_addr;
    wire [15:0] W_IR_dmem_data;
    //End new wires
    wire [15:0] W_IR_alu_result;
    wire [15:0] W_IR_rd_data;
    wire [15:0] W_IR_r1_data;
    wire [15:0] W_IR_r2_data;
    wire [2:0] W_IR_r1;
    wire [2:0] W_IR_r2;
    wire [2:0] W_IR_rd;
    wire W_IR_r1re;
    wire W_IR_r2re;
    wire W_IR_select_pc_plus_one;
    wire W_IR_is_load;
    wire W_IR_is_store;
    wire W_IR_is_branch;
    wire W_IR_is_control_insn;
    wire W_IR_regfile_we;
    wire W_IR_nzp_we;
    wire [15:0] W_IR_pc;
    wire [15:0] W_IR_insn;
    wire [1:0] W_IR_stall;
    
    //WM_reg registers
    Nbit_reg #(16, 16'h0) MW_dmem_addr (.in(M_dmem_addr), .out(W_IR_dmem_addr), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_dmem_data (.in(M_dmem_data), .out(W_IR_dmem_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    //End new registers
    Nbit_reg #(16, 16'h0) MW_alu_result (.in(M_IR_alu_result), .out(W_IR_alu_result), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_rd_data (.in(M_IR_rd_data), .out(W_IR_rd_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_r1_data (.in(M_IR_r1_data), .out(W_IR_r1_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); 
    Nbit_reg #(16, 16'h0) MW_r2_data (.in(M_r2_data), .out(W_IR_r2_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //NOT COPIED - changes in M-stage
    Nbit_reg #(3, 3'h0) MW_r1 (.in(M_IR_r1), .out(W_IR_r1), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) MW_r2 (.in(M_IR_r2), .out(W_IR_r2), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) MW_rd (.in(M_IR_rd), .out(W_IR_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_r1re (.in(M_IR_r1re), .out(W_IR_r1re), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_r2re (.in(M_IR_r2re), .out(W_IR_r2re), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_select_pc_plus_one (.in(M_IR_select_pc_plus_one), .out(W_IR_select_pc_plus_one), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_is_load (.in(M_IR_is_load), .out(W_IR_is_load), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_is_store (.in(M_IR_is_store), .out(W_IR_is_store), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_is_branch (.in(M_IR_is_branch), .out(W_IR_is_branch), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_is_control_insn (.in(M_IR_is_control_insn), .out(W_IR_is_control_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_regfile_we (.in(M_IR_regfile_we), .out(W_IR_regfile_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_nzp_we (.in(M_IR_nzp_we), .out(W_IR_nzp_we), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_pc (.in(M_IR_pc), .out(W_IR_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_insn (.in(M_IR_insn), .out(W_IR_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'h2) MW_stall (.in(M_IR_stall), .out(W_IR_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
/**********************************************WRITEBACK STAGE**********************************************/
    
    wire [15:0] W_rd_data = (W_IR_is_load) ? W_IR_dmem_data : W_IR_rd_data; //select memory data or alu result to write
    
    //set test wires
    assign test_stall = W_IR_stall;
    assign test_cur_pc = W_IR_pc;
    assign test_cur_insn = W_IR_insn;
    assign test_regfile_we = W_IR_regfile_we; 
    assign test_regfile_wsel = W_IR_rd;
    assign test_regfile_data = W_rd_data;
    assign test_nzp_we = W_IR_nzp_we;
    assign test_nzp_new_bits = (W_rd_data[15] == 1) ? 3'b100 : (W_rd_data == 16'b0) ? 3'b010 : 3'b001;
    assign test_dmem_we = W_IR_is_store;
    assign test_dmem_addr = W_IR_dmem_addr;
    assign test_dmem_data = (W_IR_is_store) ? W_IR_r2_data : (W_IR_is_load) ? W_IR_dmem_data : 16'h0;
    
`ifndef NDEBUG
   always @(posedge gwe) begin
      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.
      
      // basic if syntax:
      // if (cond) begin
      //    ...;
      //    ...;
      // end

      // Set a breakpoint on the empty $display() below
      // to step through your pipeline cycle-by-cycle.
      // You'll need to rewind the simulation to start
      // stepping from the beginning.

      // You can also simulate for XXX ns, then set the
      // breakpoint to start stepping midway through the
      // testbench.  Use the $time printouts you added above (!)
      // to figure out when your problem instruction first
      // enters the fetch stage.  Rewind your simulation,
      // run it for that many nano-seconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecimal.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      //$display(); 
   end
`endif
endmodule
