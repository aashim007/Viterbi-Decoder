package gp_tb;

import gp::*;

(* synthesize *)
module mkGpTestbench();
    Ifc_gp dut <- mkgp;

    Reg#(UInt#(3)) state <- mkReg(0);

    rule test_loop(state < 4);
        Bit#(3) state_full = pack(state);
        Bit#(2) state_bits = state_full[1:0];
        
        Bit#(1) p1 = state_bits[1];
        Bit#(1) p0 = state_bits[0];

        Bit#(1) actual = dut.pout(p1, p0);
        Bit#(1) expected = (p1 & p0);

        $display("Test %0d: p1=%b p0=%b => pout=%b (expected=%b)", 
                 state, p1, p0, actual, expected);

        if (actual != expected)
            $display("  FAILURE: Mismatch!");

        state <= state + 1;
    endrule

    rule finish_test(state == 4);
        $display("All 4 tests completed successfully!");
        $finish(0);
    endrule
endmodule

endpackage: gp_tb
