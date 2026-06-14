package ks_tb;

import ks::*;
import Vector::*;

(* synthesize *)
module mkKsTestbench();
    Ifc_ks dut <- mkKs;
    
    Reg#(UInt#(6)) test_num <- mkReg(0);
    
    rule run_test(test_num < 25);
        Bit#(32) a = 0;
        Bit#(32) b = 0;
        Bit#(1) cin = 0;
        Bit#(32) expected_sum = 0;
        Bit#(1) expected_cout = 0;
        
        case (test_num)
            0: begin  // 0 + 0 + 0
                a = 32'h00000000; b = 32'h00000000; cin = 1'b0;
                expected_sum = 32'h00000000; expected_cout = 1'b0;
            end
            1: begin  // 1 + 1 + 0
                a = 32'h00000001; b = 32'h00000001; cin = 1'b0;
                expected_sum = 32'h00000002; expected_cout = 1'b0;
            end
            2: begin  // MAX + 1 (overflow)
                a = 32'hFFFFFFFF; b = 32'h00000001; cin = 1'b0;
                expected_sum = 32'h00000000; expected_cout = 1'b1;
            end
            3: begin  // MAX + MAX
                a = 32'hFFFFFFFF; b = 32'hFFFFFFFF; cin = 1'b0;
                expected_sum = 32'hFFFFFFFE; expected_cout = 1'b1;
            end
            4: begin  // Random case
                a = 32'h12345678; b = 32'h9ABCDEF0; cin = 1'b0;
                expected_sum = 32'hACF13568; expected_cout = 1'b0;  // CORRECTED
            end

            5: begin  // 0 + 0 + 1
                a = 32'h00000000; b = 32'h00000000; cin = 1'b1;
                expected_sum = 32'h00000001; expected_cout = 1'b0;
            end
            6: begin  // MAX + 0 + 1
                a = 32'hFFFFFFFF; b = 32'h00000000; cin = 1'b1;
                expected_sum = 32'h00000000; expected_cout = 1'b1;
            end
            7: begin  // MSB overflow
                a = 32'h80000000; b = 32'h80000000; cin = 1'b0;
                expected_sum = 32'h00000000; expected_cout = 1'b1;
            end
            8: begin  // Pattern test (alternating bits)
                a = 32'hAAAAAAAA; b = 32'h55555555; cin = 1'b0;
                expected_sum = 32'hFFFFFFFF; expected_cout = 1'b0;
            end
            9: begin  // MAX + MAX + 1
                a = 32'hFFFFFFFF; b = 32'hFFFFFFFF; cin = 1'b1;
                expected_sum = 32'hFFFFFFFF; expected_cout = 1'b1;
            end
            10: begin  // Powers of 2
                a = 32'h00010000; b = 32'h00010000; cin = 1'b0;
                expected_sum = 32'h00020000; expected_cout = 1'b0;
            end
            11: begin  // Lower 16 bits overflow
                a = 32'h0000FFFF; b = 32'h00000001; cin = 1'b0;
                expected_sum = 32'h00010000; expected_cout = 1'b0;
            end
            12: begin  // Upper bits addition with carry
                a = 32'hFFFF0000; b = 32'h01000000; cin = 1'b0;
                expected_sum = 32'h00FF0000; expected_cout = 1'b1;  // CORRECTED
            end
            13: begin  // Sequential pattern
                a = 32'h11111111; b = 32'h22222222; cin = 1'b0;
                expected_sum = 32'h33333333; expected_cout = 1'b0;
            end
            14: begin  // Large numbers (signed max)
                a = 32'h7FFFFFFF; b = 32'h7FFFFFFF; cin = 1'b0;
                expected_sum = 32'hFFFFFFFE; expected_cout = 1'b0;
            end
            15: begin  // Large numbers with carry in
                a = 32'h7FFFFFFF; b = 32'h7FFFFFFF; cin = 1'b1;
                expected_sum = 32'hFFFFFFFF; expected_cout = 1'b0;
            end
            16: begin  // Byte boundary pattern
                a = 32'hF0F0F0F0; b = 32'h0F0F0F0F; cin = 1'b0;
                expected_sum = 32'hFFFFFFFF; expected_cout = 1'b0;
            end
            17: begin  // Edge case: 2^31 - 1 + 1
                a = 32'h7FFFFFFF; b = 32'h00000001; cin = 1'b0;
                expected_sum = 32'h80000000; expected_cout = 1'b0;
            end
            18: begin  // Random test 2
                a = 32'hABCDEF01; b = 32'h12345678; cin = 1'b1;
                expected_sum = 32'hBE02457A; expected_cout = 1'b0;
            end
            19: begin  // Random test 3
                a = 32'hDEADBEEF; b = 32'hCAFEBABE; cin = 1'b0;
                expected_sum = 32'hA9AC79AD; expected_cout = 1'b1;
            end
            20: begin  // All bits set in lower half
                a = 32'h0000FFFF; b = 32'h0000FFFF; cin = 1'b0;
                expected_sum = 32'h0001FFFE; expected_cout = 1'b0;
            end
            21: begin  // All bits set in upper half
                a = 32'hFFFF0000; b = 32'hFFFF0000; cin = 1'b0;
                expected_sum = 32'hFFFE0000; expected_cout = 1'b1;
            end
            22: begin  // Power of 2 addition (2^16 + 2^16)
                a = 32'h00010000; b = 32'h00010000; cin = 1'b1;
                expected_sum = 32'h00020001; expected_cout = 1'b0;
            end
            23: begin  // Large random values
                a = 32'h87654321; b = 32'h13579BDF; cin = 1'b0;
                expected_sum = 32'h9ABCDF00; expected_cout = 1'b0;
            end
            24: begin  // Near overflow
                a = 32'hFFFFFFFE; b = 32'h00000001; cin = 1'b1;
                expected_sum = 32'h00000000; expected_cout = 1'b1;
            end
        endcase
        
        let result <- dut.add(a, b, cin);
        match {.sum, .cout} = result;
        
        $display("Test %0d: %h + %h + %b", test_num, a, b, cin);
        $display("        = %h (Cout=%b)", sum, cout);
        
        if (sum == expected_sum && cout == expected_cout) begin
            $display("  PASS");
        end
        else begin
            $display("  FAIL: Expected sum=%h cout=%b", expected_sum, expected_cout);
        end
        $display("");
        
        test_num <= test_num + 1;
    endrule
    
    rule finish_test(test_num == 25);
        $display("================================");
        $display("All 25 tests completed!");
        $display("================================");
        $finish(0);
    endrule
    
endmodule

endpackage: ks_tb
