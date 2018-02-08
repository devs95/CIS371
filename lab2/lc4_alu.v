/* Dev Sharma - dsharm */

`timescale 1ns / 1ps

`default_nettype none

module lc4_alu(input  wire [15:0] i_insn,
               input wire [15:0]  i_pc,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] o_result);


	
	wire [3:0] op = i_insn[15:12];
	wire [2:0] func0 = i_insn[5:3];
	wire [1:0] func1 = i_insn[8:7];
	wire func2 = i_insn[11];
	
	//signed immediate values
	wire [8:0] imm9 = i_insn[8:0];
	wire [6:0] imm7 = i_insn[6:0];
	wire [5:0] imm6 = i_insn[5:0];
	wire [4:0] imm5 = i_insn[4:0];
	
	//unsigned immediate values
	wire [3:0] uimm4 = i_insn[3:0];
	wire [15:0] uimm7 = {8'h00, i_insn[6:0]}; 
	wire [7:0] uimm8 = i_insn[7:0];
	
	//op-code control signals
	wire is_arith = (op == 4'h1) ? 1'b1 : 1'b0;
	wire is_log = (op == 4'h5) ? 1'b1 : 1'b0;
	wire is_compare = (op == 4'h2) ? 1'b1 : 1'b0;
	wire is_shift = (op == 4'hA) ? 1'b1 : 1'b0;
	wire is_branch = (op == 4'h0) ? 1'b1 : 1'b0;
	wire is_jump = (op == 4'hC) ? 1'b1 : 1'b0;
	wire is_jump_sub = (op == 4'h4) ? 1'b1 : 1'b0;
	wire is_ldr = (op == 4'h6) ? 1'b1 : 1'b0;
	wire is_str = (op == 4'h7) ? 1'b1 : 1'b0;
	wire is_rti = (op == 4'h8) ? 1'b1 : 1'b0;
	wire is_trap = (op == 4'h15) ? 1'b1 : 1'b0;
	wire is_const = (op == 4'h9) ? 1'b1: 1'b0;
	wire is_hiconst = (op == 4'hD) ? 1'b1 : 1'b0;
	
	//arithmetic op computations
	wire [15:0] o_add = i_r1data + i_r2data;
	wire [15:0] o_mul = i_r1data * i_r2data;
	wire [15:0] o_sub = i_r1data - i_r2data;
	// MUST DO DIV!!!!
	wire [15:0] o_addi = i_r1data + imm5_ext;
	
	
	//arithmetic op muxing
	wire [15:0] o_arith = 	(func0 == 3'h0) ? o_add :
							(func0 == 3'h1) ? o_mul :
							(func0 == 3'h2) ? o_sub :
							(func0 == 3'h3) ? o_div :
							(func0[2] == 3'b1) ? o_addi;
							
	//logical op computations						
	wire [15:0] o_and = i_r1data & i_r2data;
	wire [15:0] o_not = ~i_r1data;
	wire [15:0] o_or = i_r1data | i_r2data;
	wire [15:0] o_xor = i_r1data ^ i_r2data;
	wire [15:0] o_andi = i_r1data & imm5_ext;
	
	//logical op muxing						
	wire [15:0] o_log = 	(func0 == 3'h0) ? o_and :
							(func0 == 3'h1) ? o_not :
							(func0 == 3'h2) ? o_or :
							(func0 == 3'h3) ? o_xor :
							(func0[2] == 3'b1) ? o_andi;

/***	COMPARE		***/							
	// MUST DO COMPARE COMPUTATIONS

							
	//compare op muxing
	wire [15:0] o_compare = 	(func1 == 2'h0 ? o_cmp :
								(func1 == 2'h1) ? o_cmpu :
								(func1 == 2'h2) ? o_cmpi :
								(func1 == 2'h3) ? o_cmpiu;
								
	//shift op muxing							
	wire [15:0] o_shift = 		(func0[2:1] == 2'h0) ? o_sll :
								(func0[2:1] == 2'h1) ? o_sra :
								(func0[2:1] == 2'h2) ? o_srl :
								(func0[2:1] == 2'h3) ? o_mod;
								
/***		JUMP		***/								
	
	//jump computations
	wire [15:0] o_jmpr = i_r1data;
	// MUST DO JMP
	
	//jump op muxing	
	wire [15:0] o_jump = 		(func2 == 1'b0) ? o_jmpr : o_jmp;
	
/***	JUMP TO SUB		***/	
	//jump to sub computations
	wire[15:0] o_jsrr = i_r1data;
	// MUST DO JSR
	
	//jump to sub op muxing	
	wire [15:0] o_jump_sub = 	(func2 == 1'b0) ? o_jsrr : o_jsr;
	
	//final output muxing
	assign o_result = 	is_arith ? o_arith :
						is_log ? o_log :
						is_compare ? o_compare :
						is_shift ? o_shift :
						is_branch ? o_branch :
						is_jump ? o_jump :
						is_jump_sub ? o_jump_sub :
						is_ldr ? o_ldr :
						is_str ? o_str :
						is_rti ? o_rti :
						is_trap ? o_trap :
						is_const ? o_const :
						is_hiconst ? o_hiconst :
						4'h000;
	
endmodule
