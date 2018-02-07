/* Dev Sharma - dsharm */

`timescale 1ns / 1ps

`default_nettype none

module lc4_alu(input  wire [15:0] i_insn,
               input wire [15:0]  i_pc,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] o_result);


      /*** YOUR CODE HERE ***/

endmodule

module lc4_decode(input wire [15:0] i_insn,
                    output wire [4:0] o_ctrl);
                    
    wire [15:0] arith_log_masked = i_insn & 16'hF038; //masked for ADD, MUL, SUB, DIV, ADDI, AND, NOT, OR, XOR, ANDI  
    wire [15:0] cmp_masked = i_insn & 16'hF180; //masked for CMP, CMPU, CMPI, CMPIU
    wire [15:0] shift_masked = i_insn & 16'hF030; //masked for SLL, SRA, SRL, MOD
    wire [15:0] jump_masked = i_insn & 16'hF800; //masked for JSRR, JSR, JMPR, JMP
    wire [15:0] misc_masked = i_isn & 16'hF000;
    
    o_ctrl =    (arith_log_masked == 16'h1000) ? 5'h00 : //ADD
                (arith_log_masked == 16'h1008) ? 5'h01 : //MUL
                (arith_log_masked == 16'h1010) ? 5'h02 : //SUB
                (arith_log_masked == 16'h1018) ? 5'h03 : //DIV
                ((arith_log_masked & 16'hFF20) == 16'h1020) ? 5'h04 : //ADDI
                
                (arith_log_masked == 16'h5000) ? 5'h05 : //AND
                (arith_log_masked == 16'h5008) ? 5'h06 : //NOT
                (arith_log_masked == 16'h5010) ? 5'h07 : //OR
                (arith_log_masked == 16'h5018) ? 5'h08 : //XOR
                ((arith_log_masked & 16'hFF20) == 16'h5020) ? 5'h09 : //ANDI
                
                (cmp_masked == 16'h2000) ? 5'h0A : //CMP
                (cmp_masked == 16'h2080) ? 5'h0B : //CMPU
                (cmp_masked == 16'h2100) ? 5'h0C : //CMPI
                (cmp_masked == 16'h2180) ? 5'h0D : //CMPIU
                
                (shift_masked == 16'h8000) ? 5'h0E : //SLL
                (shift_masked == 16'h8010) ? 5'h0F : //SRA
                (shift_masked == 16'h8020) ? 5'h10 : //SRL
                (shift_masked == 16'h8030) ? 5'h11 : //MOD
                
                (jump_masked == 16'h4000) ? 5'h12 : //JSRR
                (jump_masked == 16'h4800) ? 5'h13 : //JSR
                (jump_masked == 16'hC000) ? 5'h14 : //JMPR
                (jump_masked == 16'hC800) ? 5'h15 : //JMP
                
                (misc_masked == 16'h
                
                
                
                

end module
