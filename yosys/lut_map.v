// Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
//                    Technische Universitaet Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.


module \$lut (A, Y);
	parameter WIDTH = 0;
	parameter LUT = 0;

	(* force_downto *)
	input [WIDTH-1:0] A;
	output Y;

	generate
		if (WIDTH == 1) begin
			LUT1 #(.INIT(LUT)) _TECHMAP_REPLACE_ (.O(Y), .I0(A[0]));
		end
		else if (WIDTH == 2) begin
			LUT2 #(.INIT(LUT)) _TECHMAP_REPLACE_ (.O(Y), .I0(A[0]), .I1(A[1]));
		end
		else if (WIDTH == 3) begin
			LUT3 #(.INIT(LUT)) _TECHMAP_REPLACE_ (.O(Y), .I0(A[0]), .I1(A[1]), .I2(A[2]));
		end
		else if (WIDTH == 4) begin
			LUT4 #(.INIT(LUT)) _TECHMAP_REPLACE_ (.O(Y), .I0(A[0]), .I1(A[1]), .I2(A[2]), .I3(A[3]));
		end
		else begin
			wire _TECHMAP_FAIL_ = 1;
		end
	endgenerate
endmodule
