/* TODO: name and PennKeys of all group members here
 *
 * lc4_single.v
 * Implements a single-cycle data path
 *
 */

`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk,                // Main clock
    input  wire        rst,                // Global reset
    input  wire        gwe,                // Global we for single-step clock
   
    output wire [15:0] o_cur_pc,           // Address to read from instruction memory
    input  wire [15:0] i_cur_insn,         // Output of instruction memory
    output wire [15:0] o_dmem_addr,        // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
    input  wire [15:0] i_cur_dmem_data,    // Output of data memory
    output wire        o_dmem_we,          // Data memory write enable
    output wire [15:0] o_dmem_towrite,     // Value to write to data memory

    // Testbench signals are used by the testbench to verify the correctness of your datapath.
    // Many of these signals simply export internal processor state for verification (such as the PC).
    // Some signals are duplicate output signals for clarity of purpose.
    //
    // Don't forget to include these in your schematic!

    output wire [1:0]  test_stall,         // Testbench: is this a stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc,        // Testbench: program counter
    output wire [15:0] test_cur_insn,      // Testbench: instruction bits
    output wire        test_regfile_we,    // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel,  // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data,  // Testbench: value to write into the register file
    output wire        test_nzp_we,        // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits,  // Testbench: value to write to NZP bits
    output wire        test_dmem_we,       // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr,     // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data,     // Testbench: value read/writen from/to memory
   
    input  wire [7:0]  switch_data,        // Current settings of the Zedboard switches
    output wire [7:0]  led_data            // Which Zedboard LEDs should be turned on?
    );
    
    
   // By default, assign LEDs to display switch inputs to avoid warnings about
   // disconnected ports. Feel free to use this for debugging input/output if
   // you desire.
   assign led_data = switch_data;

   
   /* DO NOT MODIFY THIS CODE */
   // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
   assign test_stall = 2'b0; 

   // pc wires attached to the PC register's ports
   wire [15:0]   pc;      // Current program counter (read out from pc_reg)
   wire [15:0]   next_pc; // Next program counter (you compute this and feed it into next_pc)

   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   /* END DO NOT MODIFY THIS CODE */


   /*******************************
    * TODO: INSERT YOUR CODE HERE *
    *******************************/
    
    //Declare wires
    //NZP
    wire [2:0] nzp_in, nzp_bits;
    //NZP Branch Logic
    wire br_e;
    //Decoder
    wire r1re, r2re, regfile_we, nzp_we, is_load, is_store, is_branch, is_control_insn;
    wire [2:0] r1_addr, r2_addr, rd_addr;
    //Regfile
    wire [15:0] r1_data, r2_data, rd_data;
    //Memory
    wire [15:0] dmem_addr;
    //ALU
    wire [15:0] alu_result;
    
    
    //NZP Register
    assign nzp_in = (rd_data[15] == 1'b1) ? 3'b100 : (rd_data == 16'h0) ? 3'b010 : 3'b1;
    Nbit_reg #(3, 3'b000) NZP_reg (.in(nzp_in), .out(nzp_bits), .clk(clk), .we(nzp_we), .gwe(gwe), .rst(rst));
    
    //NZP Branch Logic
    lc4_nzp_branch_logic nzp_branch_logic(.i_nzp(nzp_bits), .i_nzp_se(i_cur_insn[11:9]), .i_is_branch(is_branch) , .o_br_e(br_e));
    
    
    //Decoder
    lc4_decoder decoder(.insn(i_cur_insn), .r1sel(r1_addr), .r1re(r1re), .r2sel(r2_addr), .r2re(r2re), .wsel(rd_addr), .regfile_we(regfile_we), .nzp_we(nzp_we), .select_pc_plus_one(),
                            .is_load(is_load), .is_store(is_store), .is_branch(is_branch), .is_control_insn(is_control_insn));
                            
    
    //Register File
    assign rd_data = (is_load) ? i_cur_dmem_data : alu_result;
    lc4_regfile regfile(.i_rd(rd_addr), .i_rs(r1_addr), .i_rt(r2_addr), .i_rd_we(regfile_we), .i_wdata(rd_data), .o_rs_data(r1_data), .o_rt_data(r2_data));
    
    //ALU
    lc4_alu alu(.i_insn(i_cur_insn), .i_pc(pc), .i_r1data(r1_data), .i_r2data(r2_data), .o_result(alu_result));
    
    //Memory
    assign dmem_addr = (is_load | is_store) ? alu_result : 16'h0;
    assign o_dmem_addr = dmem_addr;
    assign o_dmem_towrite = r1_data;
    assign o_dmem_we = is_store;
    
    //PC
    assign next_pc = (br_e | is_control_insn) ? alu_result : (pc+16'h0001);
    assign o_cur_pc = pc;
    
    //Assign test bench signals
    assign test_cur_pc = o_cur_pc;
    assign test_cur_insn = i_cur_insn;
    assign test_regfile_we = regfile_we;
    assign test_regfile_wsel = rd_addr;
    assign test_regfile_data = rd_data;
    assign test_nzp_we = nzp_we;
    assign test_nzp_new_bits = nzp_in;
    assign test_dmem_we = is_store;
    assign test_dmem_addr = dmem_addr;
    assign test_dmem_data = (is_store) ? r1_data : 16'h0;



   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    * 
    * To disable the entire block add the statement
    * `define NDEBUG
    * to the top of your file.  We also define this symbol
    * when we run the grading scripts.
    */
`ifndef NDEBUG
   always @(posedge gwe) begin
      //$display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);
      //$display 

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.
        $display("%d || PC = %h || test = %h", $time, pc, test_cur_pc);
        $display("%d || alu_result = %h", $time, alu_result);
        $display("%d || nzp_in = %b || test = %b", $time, nzp_in, test_nzp_new_bits);
        $display("%d || nzp_we = %b || test = %b", $time, nzp_we, test_nzp_we);
        
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
      // then right-click, and select Radix->Hexadecial.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      $display();
   end
`endif
endmodule

module lc4_nzp_branch_logic(input wire [2:0] i_nzp, input wire [2:0] i_nzp_se, input wire i_is_branch, output wire o_br_e);

    wire n = i_nzp[2];
    wire z = i_nzp[1];
    wire p = i_nzp[0];
    
    wire o_br_e_tmp = (i_nzp_se == 3'h0) ? 1'h0 :
                        (i_nzp_se == 3'h1) ? z :
                        (i_nzp_se == 3'h2) ? p :
                        (i_nzp_se == 3'h3) ? (p | z) :
                        (i_nzp_se == 3'h4) ? n :
                        (i_nzp_se == 3'h5) ? (n | p) :
                        (i_nzp_se == 3'h6) ?  (n | z) :
                        (n | z | p)  ;
                        
    assign o_br_e = (o_br_e_tmp & i_is_branch);
    
endmodule    
