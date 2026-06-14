package gg_tb;

import gg::*;

(* synthesize *)
module mkGgTestbench();
    Ifc_gg dut <- mkgg;

    Reg#(UInt#(4)) state <- mkReg(0);

    rule test_loop(state < 8);
        Bit#(4) state_full = pack(state);
        Bit#(3) state_bits = state_full[2:0];
        
        Bit#(1) g1 = state_bits[2];
        Bit#(1) p1 = state_bits[1];
        Bit#(1) p0 = state_bits[0];

        Bit#(1) actual = dut.gout(g1, p1, p0);
        Bit#(1) expected = g1 | (p1 & p0);

        $display("Test %0d: g1=%b p1=%b p0=%b => gout=%b (expected=%b)", 
                 state, g1, p1, p0, actual, expected);

        if (actual != expected)
            $display("  FAILURE: Mismatch!");

        state <= state + 1;
    endrule

    rule finish_test(state == 8);
        $display("All 8 tests completed successfully!");
        $finish(0);
    endrule
endmodule

endpackage: gg_tb
