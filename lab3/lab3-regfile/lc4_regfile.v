/* TODO: Names of all group members
 * TODO: PennKeys of all group members
 *
 * lc4_regfile.v
 * Implements an 8-register register file parameterized on word size.
 *
 */

`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_regfile #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,
    input  wire [  2:0] i_rs,      // rs selector
    output wire [n-1:0] o_rs_data, // rs contents
    input  wire [  2:0] i_rt,      // rt selector
    output wire [n-1:0] o_rt_data, // rt contents
    input  wire [  2:0] i_rd,      // rd selector
    input  wire [n-1:0] i_wdata,   // data to write
    input  wire         i_rd_we    // write enable
    );

   /***********************
    * TODO YOUR CODE HERE *
    ***********************/
    wire [n - 1:0] c_0, c_1, c_2, c_3, c_4, c_5, c_6, c_7;
    wire we_0, we_1, we_2, we_3, we_4, we_5, we_6, we_7;
    assign we_0 = i_rd_we == 1'b1 ? i_rd == 3'b000 ? 1'b1 : 1'b0 : 1'b0;
    assign we_1 = i_rd_we == 1'b1 ? i_rd== 3'b001 ? 1'b1 : 1'b0: 1'b0;
    assign we_2 = i_rd_we == 1'b1 ? i_rd== 3'b010 ? 1'b1 : 1'b0: 1'b0;
    assign we_3 = i_rd_we == 1'b1 ? i_rd== 3'b011 ? 1'b1 : 1'b0: 1'b0;
    assign we_4 = i_rd_we == 1'b1 ? i_rd== 3'b100 ? 1'b1 : 1'b0: 1'b0;
    assign we_5 = i_rd_we == 1'b1 ? i_rd== 3'b101 ? 1'b1 : 1'b0: 1'b0;
    assign we_6 = i_rd_we == 1'b1 ? i_rd== 3'b110 ? 1'b1 : 1'b0: 1'b0;
    assign we_7 = i_rd_we == 1'b1 ? i_rd== 3'b111 ? 1'b1 : 1'b0: 1'b0;


    Nbit_reg #(.n(n), .r(16'd0)) r0 (.in(i_wdata), .out(c_0), .clk(clk), .we(we_0), .gwe(gwe), .rst(rst));
    Nbit_reg #(.n(n), .r(16'd0)) r1 (.in(i_wdata), .out(c_1), .clk(clk), .we(we_1), .gwe(gwe), .rst(rst));
    Nbit_reg #(.n(n), .r(16'd0)) r2 (.in(i_wdata), .out(c_2), .clk(clk), .we(we_2), .gwe(gwe), .rst(rst));
    Nbit_reg #(.n(n), .r(16'd0)) r3 (.in(i_wdata), .out(c_3), .clk(clk), .we(we_3), .gwe(gwe), .rst(rst));
    Nbit_reg #(.n(n), .r(16'd0)) r4 (.in(i_wdata), .out(c_4), .clk(clk), .we(we_4), .gwe(gwe), .rst(rst));
    Nbit_reg #(.n(n), .r(16'd0)) r5 (.in(i_wdata), .out(c_5), .clk(clk), .we(we_5), .gwe(gwe), .rst(rst));
    Nbit_reg #(.n(n), .r(16'd0)) r6 (.in(i_wdata), .out(c_6), .clk(clk), .we(we_6), .gwe(gwe), .rst(rst));
    Nbit_reg #(.n(n), .r(16'd0)) r7 (.in(i_wdata), .out(c_7), .clk(clk), .we(we_7), .gwe(gwe), .rst(rst));
    assign o_rs_data = i_rs== 3'b000 ? c_0 : i_rs == 3'b001 ? c_1 : i_rs == 3'b010 ? c_2 : i_rs == 3'b011 ? c_3 : i_rs == 3'b100 ? c_4 : i_rs == 3'b101 ? c_5 : i_rs == 3'b110 ? c_6 : c_7;
    assign o_rt_data = i_rt== 3'b000 ? c_0 : i_rt == 3'b001 ? c_1 : i_rt == 3'b010 ? c_2 : i_rt == 3'b011 ? c_3 : i_rt == 3'b100 ? c_4 : i_rt == 3'b101 ? c_5 : i_rt == 3'b110 ? c_6 : c_7;

endmodule
