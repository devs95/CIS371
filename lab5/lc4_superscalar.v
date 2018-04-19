`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_processor(input wire         clk,             // main clock
                     input wire         rst,             // global reset
                     input wire         gwe,             // global we for single-step clock

                     output wire [15:0] o_cur_pc,        // address to read from instruction memory
                     input wire [15:0]  i_cur_insn_A,    // output of instruction memory (pipe A)
                     input wire [15:0]  i_cur_insn_B,    // output of instruction memory (pipe B)

                     output wire [15:0] o_dmem_addr,     // address to read/write from/to data memory
                     input wire [15:0]  i_cur_dmem_data, // contents of o_dmem_addr
                     output wire        o_dmem_we,       // data memory write enable
                     output wire [15:0] o_dmem_towrite,  // data to write to o_dmem_addr if we is set

                     // testbench signals (always emitted from the WB stage)
                     output wire [ 1:0] test_stall_A,        // is this a stall cycle?  (0: no stall,
                     output wire [ 1:0] test_stall_B,        // 1: pipeline stall, 2: branch stall, 3: load stall)

                     output wire [15:0] test_cur_pc_A,       // program counter
                     output wire [15:0] test_cur_pc_B,
                     output wire [15:0] test_cur_insn_A,     // instruction bits
                     output wire [15:0] test_cur_insn_B,
                     output wire        test_regfile_we_A,   // register file write-enable
                     output wire        test_regfile_we_B,
                     output wire [ 2:0] test_regfile_wsel_A, // which register to write
                     output wire [ 2:0] test_regfile_wsel_B,
                     output wire [15:0] test_regfile_data_A, // data to write to register file
                     output wire [15:0] test_regfile_data_B,
                     output wire        test_nzp_we_A,       // nzp register write enable
                     output wire        test_nzp_we_B,
                     output wire [ 2:0] test_nzp_new_bits_A, // new nzp bits
                     output wire [ 2:0] test_nzp_new_bits_B,
                     output wire        test_dmem_we_A,      // data memory write enable
                     output wire        test_dmem_we_B,
                     output wire [15:0] test_dmem_addr_A,    // address to read/write from/to memory
                     output wire [15:0] test_dmem_addr_B,
                     output wire [15:0] test_dmem_data_A,    // data to read/write from/to memory
                     output wire [15:0] test_dmem_data_B,

                     // zedboard switches/display/leds (ignore if you don't want to control these)
                     input  wire [ 7:0] switch_data,         // read on/off status of zedboard's 8 switches
                     output wire [ 7:0] led_data             // set on/off status of zedboard's 8 leds
                     );

   /***  YOUR CODE HERE ***/
   
   wire [1:0] stall_A;
   wire [1:0] stall_B;
   wire swap;
   wire flush;
/**********************************************FETCH STAGE**********************************************/   

   wire [15:0] F_pc_reg_out;
   wire [15:0] F_pc_A = swap ? D_IR_pc_B : F_pc_reg_out;
   wire [15:0] F_pc_B = F_pc_A + 16'h1; //PC of B will always be PC of A+1
   wire [15:0] F_next_pc = F_pc_A + 16'h2; //increment pc by 1 if only B stalls, else increment by 2
   
   wire F_we = ~load_use_A; //disable writing for load-to-use stall in pipe A
   
   Nbit_reg #(16, 16'h8200) pc_reg (.in(F_next_pc), .out(F_pc_reg_out), .clk(clk), .we(F_we), .gwe(gwe), .rst(rst)); //pc register
   
   wire [15:0] F_insn_A =  i_cur_insn_A;
   wire [15:0] F_insn_B =  i_cur_insn_B;
   
   assign o_cur_pc = F_pc_A;
   
/****Fetch-Decode Intermediate Register****/

    //FD_reg A output wires
    wire [15:0] D_IR_pc_A;
    wire [15:0] D_IR_insn_A;
    wire [1:0] D_IR_stall_A;
    //FD_reg A registers
    Nbit_reg #(16, 16'h0) FD_pc_A (.in(F_pc_A), .out(D_IR_pc_A), .clk(clk), .we(F_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) FD_insn_A (.in(F_insn_A), .out(D_IR_insn_A), .clk(clk), .we(F_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'h2) FD_stall_A (.in(2'h0), .out(D_IR_stall_A), .clk(clk), .we(F_we), .gwe(gwe), .rst(rst));
    
    
    //FD_reg B output wires
    wire [15:0] D_IR_pc_B;
    wire [15:0] D_IR_insn_B;
    wire [1:0] D_IR_stall_B;
    //FD_reg B registers
    Nbit_reg #(16, 16'h0) FD_pc_B (.in(F_pc_B), .out(D_IR_pc_B), .clk(clk), .we(F_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) FD_insn_B (.in(F_insn_B), .out(D_IR_insn_B), .clk(clk), .we(F_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'h2) FD_stall_B (.in(2'h0), .out(D_IR_stall_B), .clk(clk), .we(F_we), .gwe(gwe), .rst(rst));


/**********************************************DECODE STAGE**********************************************/

/****Stall Logic****/
    wire [2:0] D_stall_r1_A;
    wire [2:0] D_stall_r2_A;
    wire [2:0] D_stall_rd_A;
    wire D_stall_r1re_A;
    wire D_stall_r2re_A;
    wire D_stall_is_load_A;
    wire D_stall_is_store_A;
    wire D_stall_is_branch_A;
    wire D_stall_regfile_we_A;
   
    
    wire [2:0] D_stall_r1_B;
    wire [2:0] D_stall_r2_B;
    wire [2:0] D_stall_rd_B;
    wire D_stall_r1re_B;
    wire D_stall_r2re_B;
    wire D_stall_is_load_B;
    wire D_stall_is_store_B;
    wire D_stall_is_branch_B;
    wire D_stall_regfile_we_B;
    
    //Use parallel decoder to detect stalls because other decoder will be flushed with NOP when a stall is needed. Can't decode stall logic and flush the same decoder in 1 cycle
    lc4_decoder stall_decoder_A(.insn(D_IR_insn_A), .r1sel(D_stall_r1_A), .r1re(D_stall_r1re_A), .r2sel(D_stall_r2_A), .r2re(D_stall_r2re_A), .wsel(D_stall_rd_A), 
    .regfile_we(D_stall_regfile_we_A), .nzp_we(), .select_pc_plus_one(), .is_load(D_stall_is_load_A), .is_store(D_stall_is_store_A), .is_branch(D_stall_is_branch_A), .is_control_insn());
                            
    lc4_decoder stall_decoder_B(.insn(D_IR_insn_B), .r1sel(D_stall_r1_B), .r1re(D_stall_r1re_B), .r2sel(D_stall_r2_B), .r2re(D_stall_r2re_B), .wsel(D_stall_rd_B),
    .regfile_we(D_stall_regfile_we_B), .nzp_we(), .select_pc_plus_one(), .is_load(D_stall_is_load_B), .is_store(D_stall_is_store_B), .is_branch(D_stall_is_branch_B), .is_control_insn());
    
    wire load_use_A =   (   //Insn A uses load from older Pipe A insn
                            X_IR_is_load_A & //X insn A must be a load
                            (
                                ((D_stall_r1_A == X_IR_rd_A) & D_stall_r1re_A) | //D_rs_A == X_rd_A
                                ((D_stall_r2_A == X_IR_rd_A) & D_stall_r2re_A & ~D_stall_is_store_A) | //D_rt_A == X_rd_A
                                D_stall_is_branch_A //load-to-branch
                            ) 
                        ) |
                        (   // Insn A uses load from older Pipe B insn
                            X_IR_is_load_B & //X insn B must be a load
                            (
                                ((D_stall_r1_A == X_IR_rd_B) & D_stall_r1re_A) | //D_rs_A == X_rd_B
                                ((D_stall_r2_A == X_IR_rd_B) & D_stall_r2re_A & ~D_stall_is_store_A) | //D_rt_A == X_rd_B
                                D_stall_is_branch_A //load-to-branch
                            )
                        );
    
    wire load_use_B =   (   //Insn B uses load from older Pipe A insn
                            X_IR_is_load_A & //X insn A must be a load
                            (
                                ((D_stall_r1_B == X_IR_rd_A) & D_stall_r1re_B) | //D_rs_B == X_rd_A
                                ((D_stall_r2_B == X_IR_rd_A) & D_stall_r2re_B & ~D_stall_is_store_B) | //D_rt_B == X_rd_A
                                D_stall_is_branch_A //load-to-branch
                            ) 
                        ) |
                        (   // Insn B uses load from older Pipe B insn
                            X_IR_is_load_B & //X insn B must be a load
                            (
                                ((D_stall_r1_B == X_IR_rd_B) & D_stall_r1re_B) | //D_rs_B == X_rd_B
                                ((D_stall_r2_B == X_IR_rd_B) & D_stall_r2re_B & ~D_stall_is_store_B) | //D_rt_B == X_rd_B
                                D_stall_is_branch_B //load-to-branch
                            )
                        );
    
    wire ss_stall = (   //Insn B needs result of Insn A
                        D_stall_regfile_we_A &
                        (
                            ((D_stall_rd_A == D_stall_r1_B) & D_stall_r1re_B) |
                            ((D_stall_rd_A == D_stall_r2_B) & D_stall_r2re_B & ~D_stall_is_store_B)
                        )
                    ) |
                    //Both A and B access memory at same time
                    (D_stall_is_load_A & D_stall_is_load_B) |
                    (D_stall_is_load_A & D_stall_is_store_B) |
                    (D_stall_is_store_A & D_stall_is_load_B) |
                    (D_stall_is_store_A & D_stall_is_store_B);
                    
    assign swap = ss_stall | load_use_B;
                    
    wire [1:0] D_stall_A = load_use_A ? 2'h3 : D_IR_stall_A;
    wire [1:0] D_stall_B = (ss_stall | load_use_A) ? 2'h1 : load_use_B ? 2'h3 : D_IR_stall_B;
    
    //decoder A outputs
    wire [2:0] D_r1_A;
    wire [2:0] D_r2_A;
    wire [2:0] D_rd_A;
    wire D_r1re_A;
    wire D_r2re_A;
    wire D_select_pc_plus_one_A;
    wire D_is_load_A;
    wire D_is_store_A;
    wire D_is_branch_A;
    wire D_is_control_insn_A;
    wire D_regfile_we_A;
    wire D_nzp_we_A;
    
    //decoder B outputs
    wire [2:0] D_r1_B;
    wire [2:0] D_r2_B;
    wire [2:0] D_rd_B;
    wire D_r1re_B;
    wire D_r2re_B;
    wire D_select_pc_plus_one_B;
    wire D_is_load_B;
    wire D_is_store_B;
    wire D_is_branch_B;
    wire D_is_control_insn_B;
    wire D_regfile_we_B;
    wire D_nzp_we_B;
    
    wire [15:0] D_insn_A = load_use_A ? 16'h0 : D_IR_insn_A;
    wire [15:0] D_insn_B = (load_use_A | swap) ? 16'h0 : D_IR_insn_B; 

    //decoder A
    lc4_decoder decoder_A (.insn(D_insn_A), .r1sel(D_r1_A), .r1re(D_r1re_A), .r2sel(D_r2_A), .r2re(D_r2re_A), .wsel(D_rd_A), .regfile_we(D_regfile_we_A), .nzp_we(D_nzp_we_A), .select_pc_plus_one(D_select_pc_plus_one_A),
                            .is_load(D_is_load_A), .is_store(D_is_store_A), .is_branch(D_is_branch_A), .is_control_insn(D_is_control_insn_A));
    
    //decoder B
    lc4_decoder decoder_B (.insn(D_insn_B), .r1sel(D_r1_B), .r1re(D_r1re_B), .r2sel(D_r2_B), .r2re(D_r2re_B), .wsel(D_rd_B), .regfile_we(D_regfile_we_B), .nzp_we(D_nzp_we_B), .select_pc_plus_one(D_select_pc_plus_one_B),
                            .is_load(D_is_load_B), .is_store(D_is_store_B), .is_branch(D_is_branch_B), .is_control_insn(D_is_control_insn_B));

    wire [15:0] D_r1_data_A, D_r2_data_A, D_r1_data_B, D_r2_data_B; //regfile output wires
    lc4_regfile_ss regfile(.i_rs_A(D_r1_A), .i_rt_A(D_r2_A), .i_rd_A(W_IR_rd_A), .i_rd_we_A(W_IR_regfile_we_A), .i_wdata_A(W_rd_data_A), .o_rs_data_A(D_r1_data_A), .o_rt_data_A(D_r2_data_A),
                            .i_rs_B(D_r1_B), .i_rt_B(D_r2_B), .i_rd_B(W_IR_rd_B), .i_rd_we_B(W_IR_regfile_we_B), .i_wdata_B(W_rd_data_B), .o_rs_data_B(D_r1_data_B), .o_rt_data_B(D_r2_data_B),
                            .clk(clk) , .gwe(gwe), .rst(rst)); //2-pipe regfile
                                                        
/****Decode-Execute Intermediate Register****/

    //DX_reg A output wires
    wire [15:0] X_IR_r1_data_A;
    wire [15:0] X_IR_r2_data_A;
    wire [2:0] X_IR_r1_A;
    wire [2:0] X_IR_r2_A;
    wire [2:0] X_IR_rd_A;
    wire X_IR_r1re_A;
    wire X_IR_r2re_A;
    wire X_IR_select_pc_plus_one_A;
    wire X_IR_is_load_A;
    wire X_IR_is_store_A;
    wire X_IR_is_branch_A;
    wire X_IR_is_control_insn_A;
    wire X_IR_regfile_we_A;
    wire X_IR_nzp_we_A;
    wire [1:0] X_IR_stall_A;
    //End new outputs
    wire [15:0] X_IR_pc_A;
    wire [15:0] X_IR_insn_A;
    
    //DX_reg B output wires
    wire [15:0] X_IR_r1_data_B;
    wire [15:0] X_IR_r2_data_B;
    wire [2:0] X_IR_r1_B;
    wire [2:0] X_IR_r2_B;
    wire [2:0] X_IR_rd_B;
    wire X_IR_r1re_B;
    wire X_IR_r2re_B;
    wire X_IR_select_pc_plus_one_B;
    wire X_IR_is_load_B;
    wire X_IR_is_store_B;
    wire X_IR_is_branch_B;
    wire X_IR_is_control_insn_B;
    wire X_IR_regfile_we_B;
    wire X_IR_nzp_we_B;
    wire [1:0] X_IR_stall_B;
    //End new outputs
    wire [15:0] X_IR_pc_B;
    wire [15:0] X_IR_insn_B;
    
    //DX_reg A registers
    Nbit_reg #(16, 16'h0) DX_r1_data_A (.in(D_r1_data_A), .out(X_IR_r1_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) DX_r2_data_A (.in(D_r2_data_A), .out(X_IR_r2_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) DX_r1_A (.in(D_r1_A), .out(X_IR_r1_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) DX_r2_A (.in(D_r2_A), .out(X_IR_r2_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) DX_rd_A (.in(D_rd_A), .out(X_IR_rd_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_r1re_A (.in(D_r1re_A), .out(X_IR_r1re_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_r2re_A (.in(D_r2re_A), .out(X_IR_r2re_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_select_pc_plus_one_A (.in(D_select_pc_plus_one_A), .out(X_IR_select_pc_plus_one_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_is_load_A (.in(D_is_load_A), .out(X_IR_is_load_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_is_store_A (.in(D_is_store_A), .out(X_IR_is_store_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_is_branch_A (.in(D_is_branch_A), .out(X_IR_is_branch_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_is_control_insn_A (.in(D_is_control_insn_A), .out(X_IR_is_control_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_regfile_we_A (.in(D_regfile_we_A), .out(X_IR_regfile_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_nzp_we_A (.in(D_nzp_we_A), .out(X_IR_nzp_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    //End new registers
    Nbit_reg #(16, 16'h0) DX_pc_A (.in(D_IR_pc_A), .out(X_IR_pc_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) DX_insn_A (.in(D_insn_A), .out(X_IR_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'h2) DX_stall_A (.in(D_stall_A), .out(X_IR_stall_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    //DX_reg B registers
    Nbit_reg #(16, 16'h0) DX_r1_data_B (.in(D_r1_data_B), .out(X_IR_r1_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) DX_r2_data_B (.in(D_r2_data_B), .out(X_IR_r2_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) DX_r1_B (.in(D_r1_B), .out(X_IR_r1_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) DX_r2_B (.in(D_r2_B), .out(X_IR_r2_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) DX_rd_B (.in(D_rd_B), .out(X_IR_rd_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_r1re_B (.in(D_r1re_B), .out(X_IR_r1re_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_r2re_B (.in(D_r2re_B), .out(X_IR_r2re_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_select_pc_plus_one_B (.in(D_select_pc_plus_one_B), .out(X_IR_select_pc_plus_one_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_is_load_B (.in(D_is_load_B), .out(X_IR_is_load_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_is_store_B (.in(D_is_store_B), .out(X_IR_is_store_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_is_branch_B (.in(D_is_branch_B), .out(X_IR_is_branch_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_is_control_insn_B (.in(D_is_control_insn_B), .out(X_IR_is_control_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_regfile_we_B (.in(D_regfile_we_B), .out(X_IR_regfile_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) DX_nzp_we_B (.in(D_nzp_we_B), .out(X_IR_nzp_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    //End new registers
    Nbit_reg #(16, 16'h0) DX_pc_B (.in(D_IR_pc_B), .out(X_IR_pc_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) DX_insn_B (.in(D_insn_B), .out(X_IR_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'h2) DX_stall_B (.in(D_stall_B), .out(X_IR_stall_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));


/**********************************************EXECUTE STAGE**********************************************/

    //MX & WX Bypass to rs of pipe A
    wire [15:0] X_r1_data_A = ((X_IR_r1_A == M_IR_rd_B) & M_IR_regfile_we_B & X_IR_r1re_A) ? M_IR_rd_data_B : 
                              ((X_IR_r1_A == M_IR_rd_A) & M_IR_regfile_we_A & X_IR_r1re_A) ? M_IR_rd_data_A :
                              ((X_IR_r1_A == W_IR_rd_B) & W_IR_regfile_we_B & X_IR_r1re_A) ? W_rd_data_B : 
                              ((X_IR_r1_A == W_IR_rd_A) & W_IR_regfile_we_A & X_IR_r1re_A) ? W_rd_data_A :
                              X_IR_r1_data_A;
                              
    //MX & WX Bypass to rt of pipe A
    wire [15:0] X_r2_data_A = ((X_IR_r2_A == M_IR_rd_B) & M_IR_regfile_we_B & X_IR_r2re_A) ? M_IR_rd_data_B :
                              ((X_IR_r2_A == M_IR_rd_A) & M_IR_regfile_we_A & X_IR_r2re_A) ? M_IR_rd_data_A : 
                              ((X_IR_r2_A == W_IR_rd_B) & W_IR_regfile_we_B & X_IR_r2re_A) ? W_rd_data_B :
                              ((X_IR_r2_A == W_IR_rd_A) & W_IR_regfile_we_A & X_IR_r2re_A) ? W_rd_data_A :
                              X_IR_r2_data_A;
    
    //MX & WX Bypass to rs of pipe B
    wire [15:0] X_r1_data_B =   ((X_IR_r1_B == M_IR_rd_B) & M_IR_regfile_we_B & X_IR_r1re_B) ? M_IR_rd_data_B :
                                ((X_IR_r1_B == M_IR_rd_A) & M_IR_regfile_we_A & X_IR_r1re_B) ? M_IR_rd_data_A :
                                ((X_IR_r1_B == W_IR_rd_B) & W_IR_regfile_we_B & X_IR_r1re_B) ? W_rd_data_B : 
                                ((X_IR_r1_B == W_IR_rd_A) & W_IR_regfile_we_A & X_IR_r1re_B) ? W_rd_data_A :
                                X_IR_r1_data_B;
                    
    //MX & WX Bypass to rs of pipe B
    wire [15:0] X_r2_data_B =   ((X_IR_r2_B == M_IR_rd_B) & M_IR_regfile_we_B & X_IR_r2re_B) ? M_IR_rd_data_B :
                                ((X_IR_r2_B == M_IR_rd_A) & M_IR_regfile_we_A & X_IR_r2re_B) ? M_IR_rd_data_A :
                                ((X_IR_r2_B == W_IR_rd_B) & W_IR_regfile_we_B & X_IR_r2re_B) ? W_rd_data_B : 
                                ((X_IR_r2_B == W_IR_rd_A) & W_IR_regfile_we_A & X_IR_r2re_B) ? W_rd_data_A :
                                X_IR_r2_data_B;

    
    wire [15:0] X_alu_result_A, X_alu_result_B;
    
    lc4_alu alu_A(.i_insn(X_IR_insn_A), .i_pc(X_IR_pc_A), .i_r1data(X_r1_data_A), .i_r2data(X_r2_data_A), .o_result(X_alu_result_A));
    wire [15:0] X_rd_data_A = X_IR_select_pc_plus_one_A ? (X_IR_pc_A+16'b1) : X_alu_result_A;
    
    lc4_alu alu_B(.i_insn(X_IR_insn_B), .i_pc(X_IR_pc_B), .i_r1data(X_r1_data_B), .i_r2data(X_r2_data_B), .o_result(X_alu_result_B));
    wire [15:0] X_rd_data_B = X_IR_select_pc_plus_one_B ? (X_IR_pc_B+16'b1) : X_alu_result_B;
    
/****Execute-Memory Intermediate Register****/

    //XM_reg A outputs
    wire [15:0] M_IR_alu_result_A;
    wire [15:0] M_IR_rd_data_A;
    //End new outputs
    wire [15:0] M_IR_r1_data_A;
    wire [15:0] M_IR_r2_data_A;
    wire [2:0] M_IR_r1_A;
    wire [2:0] M_IR_r2_A;
    wire [2:0] M_IR_rd_A;
    wire M_IR_r1re_A;
    wire M_IR_r2re_A;
    wire M_IR_select_pc_plus_one_A;
    wire M_IR_is_load_A;
    wire M_IR_is_store_A;
    wire M_IR_is_branch_A;
    wire M_IR_is_control_insn_A;
    wire M_IR_regfile_we_A;
    wire M_IR_nzp_we_A;
    wire [15:0] M_IR_pc_A;
    wire [15:0] M_IR_insn_A;
    wire [1:0] M_IR_stall_A;
    
    //XM_reg B outputs
    wire [15:0] M_IR_alu_result_B;
    wire [15:0] M_IR_rd_data_B;
    //End new outputs
    wire [15:0] M_IR_r1_data_B;
    wire [15:0] M_IR_r2_data_B;
    wire [2:0] M_IR_r1_B;
    wire [2:0] M_IR_r2_B;
    wire [2:0] M_IR_rd_B;
    wire M_IR_r1re_B;
    wire M_IR_r2re_B;
    wire M_IR_select_pc_plus_one_B;
    wire M_IR_is_load_B;
    wire M_IR_is_store_B;
    wire M_IR_is_branch_B;
    wire M_IR_is_control_insn_B;
    wire M_IR_regfile_we_B;
    wire M_IR_nzp_we_B;
    wire [15:0] M_IR_pc_B;
    wire [15:0] M_IR_insn_B;
    wire [1:0] M_IR_stall_B;
    
    //XM_reg A registers
    Nbit_reg #(16, 16'h0) XM_alu_result_A (.in(X_alu_result_A), .out(M_IR_alu_result_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) XM_rd_data_A (.in(X_rd_data_A), .out(M_IR_rd_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    //End new registers
    Nbit_reg #(16, 16'h0) XM_r1_data_A (.in(X_r1_data_A), .out(M_IR_r1_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) XM_r2_data_A (.in(X_r2_data_A), .out(M_IR_r2_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) XM_r1_A (.in(X_IR_r1_A), .out(M_IR_r1_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) XM_r2_A (.in(X_IR_r2_A), .out(M_IR_r2_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) XM_rd_A (.in(X_IR_rd_A), .out(M_IR_rd_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_r1re_A (.in(X_IR_r1re_A), .out(M_IR_r1re_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_r2re_A (.in(X_IR_r2re_A), .out(M_IR_r2re_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_select_pc_plus_one_A (.in(X_IR_select_pc_plus_one_A), .out(M_IR_select_pc_plus_one_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_is_load_A (.in(X_IR_is_load_A), .out(M_IR_is_load_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_is_store_A (.in(X_IR_is_store_A), .out(M_IR_is_store_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_is_branch_A (.in(X_IR_is_branch_A), .out(M_IR_is_branch_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_is_control_insn_A (.in(X_IR_is_control_insn_A), .out(M_IR_is_control_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_regfile_we_A (.in(X_IR_regfile_we_A), .out(M_IR_regfile_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_nzp_we_A (.in(X_IR_nzp_we_A), .out(M_IR_nzp_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) XM_pc_A (.in(X_IR_pc_A), .out(M_IR_pc_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) XM_insn_A (.in(X_IR_insn_A), .out(M_IR_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'h2) XM_stall_A (.in(X_IR_stall_A), .out(M_IR_stall_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    //XM_reg B registers
    Nbit_reg #(16, 16'h0) XM_alu_result_B (.in(X_alu_result_B), .out(M_IR_alu_result_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) XM_rd_data_B (.in(X_rd_data_B), .out(M_IR_rd_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    //End new registers
    Nbit_reg #(16, 16'h0) XM_r1_data_B (.in(X_r1_data_B), .out(M_IR_r1_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) XM_r2_data_B (.in(X_r2_data_B), .out(M_IR_r2_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) XM_r1_B (.in(X_IR_r1_B), .out(M_IR_r1_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) XM_r2_B (.in(X_IR_r2_B), .out(M_IR_r2_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) XM_rd_B (.in(X_IR_rd_B), .out(M_IR_rd_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_r1re_B (.in(X_IR_r1re_B), .out(M_IR_r1re_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_r2re_B (.in(X_IR_r2re_B), .out(M_IR_r2re_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_select_pc_plus_one_B (.in(X_IR_select_pc_plus_one_B), .out(M_IR_select_pc_plus_one_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_is_load_B (.in(X_IR_is_load_B), .out(M_IR_is_load_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_is_store_B (.in(X_IR_is_store_B), .out(M_IR_is_store_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_is_branch_B (.in(X_IR_is_branch_B), .out(M_IR_is_branch_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_is_control_insn_B (.in(X_IR_is_control_insn_B), .out(M_IR_is_control_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_regfile_we_B (.in(X_IR_regfile_we_B), .out(M_IR_regfile_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) XM_nzp_we_B (.in(X_IR_nzp_we_B), .out(M_IR_nzp_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) XM_pc_B (.in(X_IR_pc_B), .out(M_IR_pc_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) XM_insn_B (.in(X_IR_insn_B), .out(M_IR_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'h2) XM_stall_B (.in(X_IR_stall_B), .out(M_IR_stall_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

    
/**********************************************MEMORY STAGE**********************************************/

    wire [15:0] M_dmem_addr_A = (M_IR_is_load_A | M_IR_is_store_A) ? M_IR_alu_result_A : 16'h0; 
    wire [15:0] M_dmem_addr_B = (M_IR_is_load_B | M_IR_is_store_B) ? M_IR_alu_result_B : 16'h0; 
                                
    wire [15:0] M_dmem_wdata_A =    ~M_IR_is_store_A ? 16'h0 :
                                    ((M_IR_r2_A == W_IR_rd_B) & W_IR_regfile_we_B) ? W_rd_data_B : //WM Bypass into Pipe A
                                    ((M_IR_r2_A == W_IR_rd_A) & W_IR_regfile_we_A) ? W_rd_data_A : 
                                    M_IR_r2_data_A;

    wire [15:0] M_dmem_wdata_B =    ~M_IR_is_store_B ? 16'h0 :
                                    ((M_IR_r2_B == M_IR_rd_A) & M_IR_regfile_we_A) ? M_IR_rd_data_A :
                                    ((M_IR_r2_B == W_IR_rd_B) & W_IR_regfile_we_B) ? W_rd_data_B: //WM Bypass into Pipe B
                                    ((M_IR_r2_B == W_IR_rd_A) & W_IR_regfile_we_A) ? W_rd_data_A: 
                                    M_IR_r2_data_B;
                                    
    wire [15:0] M_dmem_rdata_A = M_IR_is_load_A ? i_cur_dmem_data : 16'h0; //read current output of memory
    wire [15:0] M_dmem_rdata_B = M_IR_is_load_B ? i_cur_dmem_data : 16'h0;
    
    //assign inputs to memory 
    assign o_dmem_towrite = M_IR_is_store_A ? M_dmem_wdata_A : M_dmem_wdata_B;
    assign o_dmem_we = M_IR_is_store_A | M_IR_is_store_B;
    assign o_dmem_addr =    (M_IR_is_load_A | M_IR_is_store_A) ? M_IR_alu_result_A : 
                            (M_IR_is_load_B | M_IR_is_store_B) ? M_IR_alu_result_B :
                            16'h0;

/****Memory-Writeback Intermediate Register***/
    
    //MW_reg A outpus
    wire [15:0] W_IR_dmem_addr_A;
    wire [15:0] W_IR_dmem_wdata_A;
    wire [15:0] W_IR_dmem_rdata_A;
    //End new outputs
    wire [15:0] W_IR_alu_result_A;
    wire [15:0] W_IR_rd_data_A;
    wire [15:0] W_IR_r1_data_A;
    wire [15:0] W_IR_r2_data_A;
    wire [2:0] W_IR_r1_A;
    wire [2:0] W_IR_r2_A;
    wire [2:0] W_IR_rd_A;
    wire W_IR_r1re_A;
    wire W_IR_r2re_A;
    wire W_IR_select_pc_plus_one_A;
    wire W_IR_is_load_A;
    wire W_IR_is_store_A;
    wire W_IR_is_branch_A;
    wire W_IR_is_control_insn_A;
    wire W_IR_regfile_we_A;
    wire W_IR_nzp_we_A;
    wire [15:0] W_IR_pc_A;
    wire [15:0] W_IR_insn_A;
    wire [1:0] W_IR_stall_A;
    
    //MW_reg B outputs
    wire [15:0] W_IR_dmem_addr_B;
    wire [15:0] W_IR_dmem_wdata_B;
    wire [15:0] W_IR_dmem_rdata_B;
    //End new outputs
    wire [15:0] W_IR_alu_result_B;
    wire [15:0] W_IR_rd_data_B;
    wire [15:0] W_IR_r1_data_B;
    wire [15:0] W_IR_r2_data_B;
    wire [2:0] W_IR_r1_B;
    wire [2:0] W_IR_r2_B;
    wire [2:0] W_IR_rd_B;
    wire W_IR_r1re_B;
    wire W_IR_r2re_B;
    wire W_IR_select_pc_plus_one_B;
    wire W_IR_is_load_B;
    wire W_IR_is_store_B;
    wire W_IR_is_branch_B;
    wire W_IR_is_control_insn_B;
    wire W_IR_regfile_we_B;
    wire W_IR_nzp_we_B;
    wire [15:0] W_IR_pc_B;
    wire [15:0] W_IR_insn_B;
    wire [1:0] W_IR_stall_B;
    
    //MW_reg A registers
    Nbit_reg #(16, 16'h0) MW_dmem_addr_A (.in(M_dmem_addr_A), .out(W_IR_dmem_addr_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_dmem_wdata_A (.in(M_dmem_wdata_A), .out(W_IR_dmem_wdata_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_dmem_rdata_A (.in(M_dmem_rdata_A), .out(W_IR_dmem_rdata_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    //End new registers
    Nbit_reg #(16, 16'h0) MW_alu_result_A (.in(M_IR_alu_result_A), .out(W_IR_alu_result_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_rd_data_A (.in(M_IR_rd_data_A), .out(W_IR_rd_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_r1_data_A (.in(M_IR_r1_data_A), .out(W_IR_r1_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_r2_data_A (.in(M_IR_r2_data_A), .out(W_IR_r2_data_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) MW_r1_A (.in(M_IR_r1_A), .out(W_IR_r1_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) MW_r2_A (.in(M_IR_r2_A), .out(W_IR_r2_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) MW_rd_A (.in(M_IR_rd_A), .out(W_IR_rd_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_r1re_A (.in(M_IR_r1re_A), .out(W_IR_r1re_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_r2re_A (.in(M_IR_r2re_A), .out(W_IR_r2re_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_select_pc_plus_one_A (.in(M_IR_select_pc_plus_one_A), .out(W_IR_select_pc_plus_one_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_is_load_A (.in(M_IR_is_load_A), .out(W_IR_is_load_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_is_store_A (.in(M_IR_is_store_A), .out(W_IR_is_store_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_is_branch_A (.in(M_IR_is_branch_A), .out(W_IR_is_branch_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_is_control_insn_A (.in(M_IR_is_control_insn_A), .out(W_IR_is_control_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_regfile_we_A (.in(M_IR_regfile_we_A), .out(W_IR_regfile_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_nzp_we_A (.in(M_IR_nzp_we_A), .out(W_IR_nzp_we_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_pc_A (.in(M_IR_pc_A), .out(W_IR_pc_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_insn_A (.in(M_IR_insn_A), .out(W_IR_insn_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'h2) MW_stall_A (.in(M_IR_stall_A), .out(W_IR_stall_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    //MW_reg B registers
    Nbit_reg #(16, 16'h0) MW_dmem_addr_B (.in(M_dmem_addr_B), .out(W_IR_dmem_addr_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_dmem_wdata_B (.in(M_dmem_wdata_B), .out(W_IR_dmem_wdata_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_dmem_rdata_B (.in(M_dmem_rdata_B), .out(W_IR_dmem_rdata_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    //End new registers
    Nbit_reg #(16, 16'h0) MW_alu_result_B (.in(M_IR_alu_result_B), .out(W_IR_alu_result_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_rd_data_B (.in(M_IR_rd_data_B), .out(W_IR_rd_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_r1_data_B (.in(M_IR_r1_data_B), .out(W_IR_r1_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_r2_data_B (.in(M_IR_r2_data_B), .out(W_IR_r2_data_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) MW_r1_B (.in(M_IR_r1_B), .out(W_IR_r1_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) MW_r2_B (.in(M_IR_r2_B), .out(W_IR_r2_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'h0) MW_rd_B (.in(M_IR_rd_B), .out(W_IR_rd_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_r1re_B (.in(M_IR_r1re_B), .out(W_IR_r1re_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_r2re_B (.in(M_IR_r2re_B), .out(W_IR_r2re_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_select_pc_plus_one_B (.in(M_IR_select_pc_plus_one_B), .out(W_IR_select_pc_plus_one_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_is_load_B (.in(M_IR_is_load_B), .out(W_IR_is_load_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_is_store_B (.in(M_IR_is_store_B), .out(W_IR_is_store_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_is_branch_B (.in(M_IR_is_branch_B), .out(W_IR_is_branch_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_is_control_insn_B (.in(M_IR_is_control_insn_B), .out(W_IR_is_control_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_regfile_we_B (.in(M_IR_regfile_we_B), .out(W_IR_regfile_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'h0) MW_nzp_we_B (.in(M_IR_nzp_we_B), .out(W_IR_nzp_we_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_pc_B (.in(M_IR_pc_B), .out(W_IR_pc_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'h0) MW_insn_B (.in(M_IR_insn_B), .out(W_IR_insn_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'h2) MW_stall_B (.in(M_IR_stall_B), .out(W_IR_stall_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
/**********************************************WRITEBACK STAGE**********************************************/

    wire [15:0] W_rd_data_A = W_IR_is_load_A ? W_IR_dmem_rdata_A : W_IR_rd_data_A; //select memory data or alu result to write
    wire [15:0] W_rd_data_B = W_IR_is_load_B ? W_IR_dmem_rdata_B : W_IR_rd_data_B; //select memory data or alu result to write
    
    //set test wires
    assign test_stall_A = W_IR_stall_A;
    assign test_cur_pc_A = W_IR_pc_A;
    assign test_cur_insn_A = W_IR_insn_A;
    assign test_regfile_we_A = W_IR_regfile_we_A; 
    assign test_regfile_wsel_A = W_IR_rd_A;
    assign test_regfile_data_A = W_rd_data_A;
    assign test_nzp_we_A = W_IR_nzp_we_A;
    assign test_nzp_new_bits_A = (W_rd_data_A[15] == 1) ? 3'b100 : (W_rd_data_A == 16'b0) ? 3'b010 : 3'b001;
    assign test_dmem_we_A = W_IR_is_store_A;
    assign test_dmem_addr_A = W_IR_dmem_addr_A;
    assign test_dmem_data_A = W_IR_is_store_A ? W_IR_dmem_wdata_A : W_IR_dmem_rdata_A;
    
    assign test_stall_B = W_IR_stall_B;
    assign test_cur_pc_B = W_IR_pc_B;
    assign test_cur_insn_B = W_IR_insn_B;
    assign test_regfile_we_B = W_IR_regfile_we_B; 
    assign test_regfile_wsel_B = W_IR_rd_B;
    assign test_regfile_data_B = W_rd_data_B;
    assign test_nzp_we_B = W_IR_nzp_we_B;
    assign test_nzp_new_bits_B = (W_rd_data_B[15] == 1) ? 3'b100 : (W_rd_data_B == 16'b0) ? 3'b010 : 3'b001;
    assign test_dmem_we_B = W_IR_is_store_B;
    assign test_dmem_addr_B = W_IR_dmem_addr_B;
    assign test_dmem_data_B = W_IR_is_store_B ? W_IR_dmem_wdata_B : W_IR_dmem_rdata_B;
    
   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    */
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
        /*
        $display("%d W_pc_A = %h || W_pc_B = %h || W_stall_A = %d || W_stall_B = %d || W_insn_A = %h || W_insn_B = %h || F_pc_A = %h || F_next_pc = %h || || F_stall_A = %d || F_stall_B = %d", $time, W_IR_pc_A, W_IR_pc_B, W_IR_stall_A, W_IR_stall_B, W_IR_insn_A, W_IR_insn_B, F_pc_A, F_next_pc, stall_A, stall_B);*/
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
      // run it for that many nanoseconds, then set
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
endmodule
