`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

/* 8-register, n-bit register file with
 * four read ports and two write ports
 * to support two pipes.
 * 
 * If both pipes try to write to the
 * same register, pipe B wins.
 * 
 * Inputs should be bypassed to the outputs
 * as needed so the register file returns
 * data that is written immediately
 * rather than only on the next cycle.
 */
module lc4_regfile_ss #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,

    input  wire [  2:0] i_rs_A,      // pipe A: rs selector
    output wire [n-1:0] o_rs_data_A, // pipe A: rs contents
    input  wire [  2:0] i_rt_A,      // pipe A: rt selector
    output wire [n-1:0] o_rt_data_A, // pipe A: rt contents

    input  wire [  2:0] i_rs_B,      // pipe B: rs selector
    output wire [n-1:0] o_rs_data_B, // pipe B: rs contents
    input  wire [  2:0] i_rt_B,      // pipe B: rt selector
    output wire [n-1:0] o_rt_data_B, // pipe B: rt contents

    input  wire [  2:0]  i_rd_A,     // pipe A: rd selector
    input  wire [n-1:0]  i_wdata_A,  // pipe A: data to write
    input  wire          i_rd_we_A,  // pipe A: write enable

    input  wire [  2:0]  i_rd_B,     // pipe B: rd selector
    input  wire [n-1:0]  i_wdata_B,  // pipe B: data to write
    input  wire          i_rd_we_B   // pipe B: write enable
    );

   /*** TODO: Your Code Here ***/
    wire [n-1:0] r0_in, r1_in, r2_in, r3_in, r4_in, r5_in, r6_in, r7_in; //register inputs
    wire [n-1:0] r0_out, r1_out, r2_out, r3_out, r4_out, r5_out, r6_out, r7_out; //register outputs
    wire we_0, we_1, we_2, we_3, we_4, we_5, we_6, we_7; //register write enables
	
	//assign register inputs
	assign r0_in = ((i_rd_B == 3'h0) && i_rd_we_B) ? i_wdata_B : i_wdata_A;
	assign r1_in = ((i_rd_B == 3'h1) && i_rd_we_B) ? i_wdata_B : i_wdata_A;
	assign r2_in = ((i_rd_B == 3'h2) && i_rd_we_B) ? i_wdata_B : i_wdata_A;
	assign r3_in = ((i_rd_B == 3'h3) && i_rd_we_B) ? i_wdata_B : i_wdata_A;
	assign r4_in = ((i_rd_B == 3'h4) && i_rd_we_B) ? i_wdata_B : i_wdata_A;
	assign r5_in = ((i_rd_B == 3'h5) && i_rd_we_B) ? i_wdata_B : i_wdata_A;
	assign r6_in = ((i_rd_B == 3'h6) && i_rd_we_B) ? i_wdata_B : i_wdata_A;
	assign r7_in = ((i_rd_B == 3'h7) && i_rd_we_B) ? i_wdata_B : i_wdata_A;
	
	//assign register write enables
	assign we_0 = ((i_rd_A == 3'h0) & i_rd_we_A) | ((i_rd_B == 3'h0) & i_rd_we_B);
	assign we_1 = ((i_rd_A == 3'h1) & i_rd_we_A) | ((i_rd_B == 3'h1) & i_rd_we_B);
	assign we_2 = ((i_rd_A == 3'h2) & i_rd_we_A) | ((i_rd_B == 3'h2) & i_rd_we_B);
	assign we_3 = ((i_rd_A == 3'h3) & i_rd_we_A) | ((i_rd_B == 3'h3) & i_rd_we_B);
	assign we_4 = ((i_rd_A == 3'h4) & i_rd_we_A) | ((i_rd_B == 3'h4) & i_rd_we_B);
	assign we_5 = ((i_rd_A == 3'h5) & i_rd_we_A) | ((i_rd_B == 3'h5) & i_rd_we_B);
	assign we_6 = ((i_rd_A == 3'h6) & i_rd_we_A) | ((i_rd_B == 3'h6) & i_rd_we_B);
	assign we_7 = ((i_rd_A == 3'h7) & i_rd_we_A) | ((i_rd_B == 3'h7) & i_rd_we_B);
	
	//instantiate each register
    Nbit_reg #(.n(n), .r(16'd0)) r0 (.in(r0_in), .out(r0_out), .clk(clk), .we(we_0), .gwe(gwe), .rst(rst));
    Nbit_reg #(.n(n), .r(16'd0)) r1 (.in(r1_in), .out(r1_out), .clk(clk), .we(we_1), .gwe(gwe), .rst(rst));
    Nbit_reg #(.n(n), .r(16'd0)) r2 (.in(r2_in), .out(r2_out), .clk(clk), .we(we_2), .gwe(gwe), .rst(rst));
    Nbit_reg #(.n(n), .r(16'd0)) r3 (.in(r3_in), .out(r3_out), .clk(clk), .we(we_3), .gwe(gwe), .rst(rst));
    Nbit_reg #(.n(n), .r(16'd0)) r4 (.in(r4_in), .out(r4_out), .clk(clk), .we(we_4), .gwe(gwe), .rst(rst));
    Nbit_reg #(.n(n), .r(16'd0)) r5 (.in(r5_in), .out(r5_out), .clk(clk), .we(we_5), .gwe(gwe), .rst(rst));
    Nbit_reg #(.n(n), .r(16'd0)) r6 (.in(r6_in), .out(r6_out), .clk(clk), .we(we_6), .gwe(gwe), .rst(rst));
    Nbit_reg #(.n(n), .r(16'd0)) r7 (.in(r7_in), .out(r7_out), .clk(clk), .we(we_7), .gwe(gwe), .rst(rst));
	
	//assign rs of pipe A
	assign o_rs_data_A = 	((i_rs_A == i_rd_B) && i_rd_we_B) ? i_wdata_B : //WD Bypass from B data input
							((i_rs_A == i_rd_A) && i_rd_we_A) ? i_wdata_A : //WD Bypass from A data input
							(i_rs_A == 3'h0) ? r0_out :
							(i_rs_A == 3'h1) ? r1_out :
							(i_rs_A == 3'h2) ? r2_out :
							(i_rs_A == 3'h3) ? r3_out :
							(i_rs_A == 3'h4) ? r4_out :
							(i_rs_A == 3'h5) ? r5_out :
							(i_rs_A == 3'h6) ? r6_out :
							r7_out; 
	
	//assign rt of pipe A	
	assign o_rt_data_A = 	((i_rt_A == i_rd_B) && i_rd_we_B) ? i_wdata_B : //WD Bypass from B data input
							((i_rt_A == i_rd_A) && i_rd_we_A) ? i_wdata_A : //WD Bypass from A data input
							(i_rt_A == 3'h0) ? r0_out :
							(i_rt_A == 3'h1) ? r1_out :
							(i_rt_A == 3'h2) ? r2_out :
							(i_rt_A == 3'h3) ? r3_out :
							(i_rt_A == 3'h4) ? r4_out :
							(i_rt_A == 3'h5) ? r5_out :
							(i_rt_A == 3'h6) ? r6_out :
							r7_out;
	
	//assign rs of pipe B
	assign o_rs_data_B = 	((i_rs_B == i_rd_B) && i_rd_we_B) ? i_wdata_B : //WD Bypass from B data input
							((i_rs_B == i_rd_A) && i_rd_we_A) ? i_wdata_A : //WD Bypass from A data input
							(i_rs_B == 3'h0) ? r0_out :
							(i_rs_B == 3'h1) ? r1_out :
							(i_rs_B == 3'h2) ? r2_out :
							(i_rs_B == 3'h3) ? r3_out :
							(i_rs_B == 3'h4) ? r4_out :
							(i_rs_B == 3'h5) ? r5_out :
							(i_rs_B == 3'h6) ? r6_out :
							r7_out; 
	
	//assign rt of pipe B
	assign o_rt_data_B = 	((i_rt_B == i_rd_B) && i_rd_we_B) ? i_wdata_B : //WD Bypass from B data input
							((i_rt_B == i_rd_A) && i_rd_we_A) ? i_wdata_A : //WD Bypass from A data input
							(i_rt_B == 3'h0) ? r0_out :
							(i_rt_B == 3'h1) ? r1_out :
							(i_rt_B == 3'h2) ? r2_out :
							(i_rt_B == 3'h3) ? r3_out :
							(i_rt_B == 3'h4) ? r4_out :
							(i_rt_B == 3'h5) ? r5_out :
							(i_rt_B == 3'h6) ? r6_out :
							r7_out; 
   
endmodule
