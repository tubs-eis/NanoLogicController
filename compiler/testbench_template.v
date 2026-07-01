// Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
//                    Technische Universitaet Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.


module testbench;

reg clk;
reg rst;

reg  [INPUT_WIDTH-1:0] inputs;
wire [OUTPUT_WIDTH-1:0] outputs;

MODULE_NAME dut (
PORT_CONNECTIONS
);

integer file;
integer i;

initial begin

file = $fopen("outputs_dut.txt","w");

inputs = INPUT_VALUE;

// --------------------
// RESET PHASE
// --------------------
rst = 0;
clk = 0;
// --------------------
#1
//#1 clk = 1;
//#1 clk = 0;

// --------------------
// release reset
rst = 1;

// --------------------
// NORMAL OPERATION
// --------------------
$fdisplay(file,"%b", outputs);
for (i = 0; i < NUM_CYCLES; i = i + 1) begin

    #1 clk = 1;
    #1 clk = 0;

    $fdisplay(file,"%b", outputs);

end

$fclose(file);

// FOR SMOKE TEST ONLY
// for (i = 0; i < 1000000; i = i + 1) begin
//     #1 clk = 1;
//     #1 clk = 0;

//     inputs = ~inputs;
// end
//

$finish;

end

endmodule
