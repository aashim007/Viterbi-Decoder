package fp_adder_tb;

import fp_adder::*;
import Vector::*;

(* synthesize *)
module mkFpAdderTestbench();
    Ifc_fp_adder dut <- mkFpAdder;
    
    Reg#(UInt#(6)) test_num <- mkReg(0);
    Reg#(UInt#(6)) max_test_num <- mkReg(26);
    
    rule run_test(test_num < max_test_num);
        Bit#(32) a = 0;
        Bit#(32) b = 0;
        Bit#(32) expected_result = 0;
        
        case (test_num)
            0: begin  // Very small values: -0.0001 + -0.0001
                a = 32'hB8D1B717;  // -0.0001
                b = 32'hB8D1B717;  // -0.0001
                expected_result = 32'hB951B717;  // Correct
            end
            1: begin  // Small + medium: -0.001 + -0.5
                a = 32'hBA83126F;  // -0.001
                b = 32'hBF000000;  // -0.5
                expected_result = 32'hBF004189;  // Correct
            end
            2: begin  // Edge: -0.01 + -0.01
                a = 32'hBC23D70A;  // -0.01
                b = 32'hBC23D70A;  // -0.01
                expected_result = 32'hBCA3D70A;  // Correct
            end
            3: begin  // Near boundary: -0.1 + -0.1
                a = 32'hBDCCCCCD;  // -0.1
                b = 32'hBDCCCCCD;  // -0.1
                expected_result = 32'hBE4CCCCD;  // Correct
            end
            4: begin  // Large difference: -8.0 + -0.001
                a = 32'hC1000000;  // -8.0
                b = 32'hBA83126F;  // -0.001
                expected_result = 32'hC1000418;  // CORRECTED
            end
            5: begin  // Edge case: -1.0 + -8.0 = -9.0
                a = 32'hBF800000;  // -1.0
                b = 32'hC1000000;  // -8.0
                expected_result = 32'hC1100000;  // Correct
            end
            6: begin  // Very close to ln(0.0001): -9.0 + -0.2
                a = 32'hC1100000;  // -9.0
                b = 32'hBE4CCCCD;  // -0.2
                expected_result = 32'hC1133333;  // Correct
            end
            7: begin  // Small values: -0.0625 + -0.0625
                a = 32'hBD800000;  // -0.0625
                b = 32'hBD800000;  // -0.0625
                expected_result = 32'hBE000000;  // Correct
            end
            8: begin  // Medium range: -2.5 + -2.5
                a = 32'hC0200000;  // -2.5
                b = 32'hC0200000;  // -2.5
                expected_result = 32'hC0A00000;  // Correct
            end
            9: begin  // Large exp diff: -5.0 + -0.0001
                a = 32'hC0A00000;  // -5.0
                b = 32'hB8D1B717;  // -0.0001
                expected_result = 32'hC0A000D1;  // CORRECTED
            end
            10: begin  // Edge: -4.0 + -4.0 = -8.0
                a = 32'hC0800000;  // -4.0
                b = 32'hC0800000;  // -4.0
                expected_result = 32'hC1000000;  // Correct
            end
            11: begin  // Small precision: -0.03125 + -0.03125
                a = 32'hBD000000;  // -0.03125
                b = 32'hBD000000;  // -0.03125
                expected_result = 32'hBD800000;  // Correct
            end
            12: begin  // Mixed: -1.5 + -7.5 = -9.0
                a = 32'hBFC00000;  // -1.5
                b = 32'hC0F00000;  // -7.5
                expected_result = 32'hC1100000;  // Correct
            end
            13: begin  // Near zero: -0.25 + -0.5
                a = 32'hBE800000;  // -0.25
                b = 32'hBF000000;  // -0.5
                expected_result = 32'hBF400000;  // Correct
            end
            14: begin  // Large exp diff: -7.0 + -0.01
                a = 32'hC0E00000;  // -7.0
                b = 32'hBC23D70A;  // -0.01
                expected_result = 32'hC0E051EB;  // Correct
            end
            15: begin  // Edge normalization: -4.5 + -4.5
                a = 32'hC0900000;  // -4.5
                b = 32'hC0900000;  // -4.5
                expected_result = 32'hC1100000;  // Correct
            end
            16: begin  // Very small: -0.00001 + -0.00001
                a = 32'hB7279620;  // -0.00001
                b = 32'hB7279620;  // -0.00001
                expected_result = 32'hB7A79620;  // Correct
            end
            17: begin  // Boundary: -3.0 + -6.0 = -9.0
                a = 32'hC0400000;  // -3.0
                b = 32'hC0C00000;  // -6.0
                expected_result = 32'hC1100000;  // Correct
            end
            18: begin  // Mixed small: -0.5 + -0.01
                a = 32'hBF000000;  // -0.5
                b = 32'hBC23D70A;  // -0.01
                expected_result = 32'hBF028F5C;  // Correct
            end
            19: begin  // Large values: -6.5 + -2.5
                a = 32'hC0D00000;  // -6.5
                b = 32'hC0200000;  // -2.5
                expected_result = 32'hC1100000;  // Correct
            end
            20: begin  // Precision test: -1.25 + -0.125
                a = 32'hBFA00000;  // -1.25
                b = 32'hBE000000;  // -0.125
                expected_result = 32'hBFB00000;  // Correct
            end
            21: begin  // Near max: -8.5 + -0.5
                a = 32'hC1080000;  // -8.5
                b = 32'hBF000000;  // -0.5
                expected_result = 32'hC1100000;  // Correct
            end
            22: begin  // Very large exp diff: -9.0 + -0.00001
                a = 32'hC1100000;  // -9.0
                b = 32'hB7279620;  // -0.00001
                expected_result = 32'hC110000A;  // CORRECTED
            end
            23: begin  // Fractional: -2.75 + -3.25
                a = 32'hC0300000;  // -2.75
                b = 32'hC0500000;  // -3.25
                expected_result = 32'hC0C00000;  // Correct
            end
            24: begin  // Final edge: -0.875 + -8.125
                a = 32'hBF600000;  // -0.875
                b = 32'hC1020000;  // -8.125
                expected_result = 32'hC1100000;  // Correct
            end
            25: begin // Custom-Test-1: 
                a = 32'h4282999A;  // 65.3
                b = 32'h4144CCCD;  // 12.3
                expected_result = 32'hC1100000;  // Ans = 77.600006103515625 
                // WRONG: result_obtained = c29b3333 = -77.6 (not +77.6)
            end

        endcase
        
        let result <- dut.add(a, b);
        
        $display("Test %0d:", test_num);
        $display("  A = %h (Exp=%d, Mant=%h)", a, a[30:23], a[22:0]);
        $display("  B = %h (Exp=%d, Mant=%h)", b, b[30:23], b[22:0]);
        $display("  Result = %h (Exp=%d, Mant=%h)", result, result[30:23], result[22:0]);
        
        if (result == expected_result) begin
            $display("  PASS");
        end
        else begin
            $display("  FAIL: Expected %h", expected_result);
        end
        $display("");
        
        test_num <= test_num + 1;
    endrule
    
    rule finish_test(test_num == max_test_num);
        $display("================================");
        $display("All %d tests completed!", max_test_num);
        $display("Range: ln(0.0001) to ln(1) ≈ [-9.21, 0]");
        $display("================================");
        $finish(0);
    endrule
    
endmodule

endpackage: fp_adder_tb
