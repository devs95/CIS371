/* Dev Sharma - dsharm */

`timescale 1ns / 1ps
`default_nettype none



module lc4_divider_one_iter(input  wire [15:0] i_dividend,
                            input  wire [15:0] i_divisor,
                            input  wire [15:0] i_remainder,
                            input  wire [15:0] i_quotient,
                            output wire [15:0] o_dividend,
                            output wire [15:0] o_remainder,
                            output wire [15:0] o_quotient);

	wire [15:0] remainder_temp, quotient_temp;
	assign remainder_temp = (i_remainder << 1) | ((i_dividend >> 15)&16'h0001);
	assign quotient_temp = i_quotient << 1;
	assign o_quotient = 	(i_divisor == 16'h0000) ? 16'h0000 :
				(remainder_temp < i_divisor) ? quotient_temp : 
				(quotient_temp | 16'h0001);
	assign o_remainder = 	(i_divisor == 16'h0000) ? 16'h0000 : 
				(remainder_temp < i_divisor) ? remainder_temp : 
				(remainder_temp - i_divisor);
	assign o_dividend = i_dividend << 1;
 
endmodule

module lc4_divider(input  wire [15:0] i_dividend,
                   input  wire [15:0] i_divisor,
                   output wire [15:0] o_remainder,
                   output wire [15:0] o_quotient);

      wire [15:0] dvd0, dvd1, dvd2, dvd3, dvd4, dvd5, dvd6, dvd7, dvd8, dvd9, dvd10, dvd11, dvd12, dvd13, dvd14, dvd15;
      wire [15:0] rem0, rem1, rem2, rem3, rem4, rem5, rem6, rem7, rem8, rem9, rem10, rem11, rem12, rem13, rem14, rem15; 
      wire [15:0] quo0, quo1, quo2, quo3, quo4, quo5, quo6, quo7, quo8, quo9, quo10, quo11, quo12, quo13, quo14, quo15; 
      lc4_divider_one_iter div0(.i_dividend(i_dividend), .i_divisor(i_divisor), .i_remainder(16'h0000), .i_quotient(16'h0000), .o_dividend(dvd0), .o_remainder(rem0), .o_quotient(quo0));
      lc4_divider_one_iter div1(.i_dividend(dvd0), .i_divisor(i_divisor), .i_remainder(rem0), .i_quotient(quo0), .o_dividend(dvd1), .o_remainder(rem1), .o_quotient(quo1));
      lc4_divider_one_iter div2(.i_dividend(dvd1), .i_divisor(i_divisor), .i_remainder(rem1), .i_quotient(quo1), .o_dividend(dvd2), .o_remainder(rem2), .o_quotient(quo2));
      lc4_divider_one_iter div3(.i_dividend(dvd2), .i_divisor(i_divisor), .i_remainder(rem2), .i_quotient(quo2), .o_dividend(dvd3), .o_remainder(rem3), .o_quotient(quo3));
      lc4_divider_one_iter div4(.i_dividend(dvd3), .i_divisor(i_divisor), .i_remainder(rem3), .i_quotient(quo3), .o_dividend(dvd4), .o_remainder(rem4), .o_quotient(quo4));
      lc4_divider_one_iter div5(.i_dividend(dvd4), .i_divisor(i_divisor), .i_remainder(rem4), .i_quotient(quo4), .o_dividend(dvd5), .o_remainder(rem5), .o_quotient(quo5));
      lc4_divider_one_iter div6(.i_dividend(dvd5), .i_divisor(i_divisor), .i_remainder(rem5), .i_quotient(quo5), .o_dividend(dvd6), .o_remainder(rem6), .o_quotient(quo6));
      lc4_divider_one_iter div7(.i_dividend(dvd6), .i_divisor(i_divisor), .i_remainder(rem6), .i_quotient(quo6), .o_dividend(dvd7), .o_remainder(rem7), .o_quotient(quo7));
      lc4_divider_one_iter div8(.i_dividend(dvd7), .i_divisor(i_divisor), .i_remainder(rem7), .i_quotient(quo7), .o_dividend(dvd8), .o_remainder(rem8), .o_quotient(quo8));
      lc4_divider_one_iter div9(.i_dividend(dvd8), .i_divisor(i_divisor), .i_remainder(rem8), .i_quotient(quo8), .o_dividend(dvd9), .o_remainder(rem9), .o_quotient(quo9));
      lc4_divider_one_iter div10(.i_dividend(dvd9), .i_divisor(i_divisor), .i_remainder(rem9), .i_quotient(quo9), .o_dividend(dvd10), .o_remainder(rem10), .o_quotient(quo10));
      lc4_divider_one_iter div11(.i_dividend(dvd10), .i_divisor(i_divisor), .i_remainder(rem10), .i_quotient(quo10), .o_dividend(dvd11), .o_remainder(rem11), .o_quotient(quo11));
      lc4_divider_one_iter div12(.i_dividend(dvd11), .i_divisor(i_divisor), .i_remainder(rem11), .i_quotient(quo11), .o_dividend(dvd12), .o_remainder(rem12), .o_quotient(quo12));
      lc4_divider_one_iter div13(.i_dividend(dvd12), .i_divisor(i_divisor), .i_remainder(rem12), .i_quotient(quo12), .o_dividend(dvd13), .o_remainder(rem13), .o_quotient(quo13));
      lc4_divider_one_iter div14(.i_dividend(dvd13), .i_divisor(i_divisor), .i_remainder(rem13), .i_quotient(quo13), .o_dividend(dvd14), .o_remainder(rem14), .o_quotient(quo14));
      lc4_divider_one_iter div15(.i_dividend(dvd14), .i_divisor(i_divisor), .i_remainder(rem14), .i_quotient(quo14), .o_dividend(), .o_remainder(rem15), .o_quotient(quo15));
      
      assign o_quotient = (i_divisor != 16'h0000) ? quo15 : 16'h0000;
      assign o_remainder = (i_divisor != 16'h0000) ? rem15 : 16'h0000;
    
endmodule // lc4_divider
