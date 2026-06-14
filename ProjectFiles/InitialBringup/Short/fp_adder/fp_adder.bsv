package fp_adder;

import ks::*;
import Vector::*;

interface Ifc_fp_adder;
    method ActionValue#(Bit#(32)) add(Bit#(32) a, Bit#(32) b);
endinterface: Ifc_fp_adder

(* synthesize *)
module mkFpAdder(Ifc_fp_adder);
    
    Ifc_ks ks_adder <- mkKs;
    
    method ActionValue#(Bit#(32)) add(Bit#(32) a, Bit#(32) b);
        
        // Extract exponent and mantissa from A and B
        Bit#(8) exp_a = a[30:23];
        Bit#(23) mantissa_a = a[22:0];
        Bit#(8) exp_b = b[30:23];
        Bit#(23) mantissa_b = b[22:0];
        
        // Variables for aligned mantissas and output exponent
        Bit#(24) ma = 0;
        Bit#(24) mb = 0;
        Bit#(8) exp_out = 0;
        
        // Align exponents by shifting mantissa
        if (exp_a > exp_b) begin
            ma = {1'b1, mantissa_a};
            Bit#(8) shift_amt = exp_a - exp_b; // i have to use a subtractor here
            
            // Perform shift with rounding
            Bit#(24) mb_full = {1'b1, mantissa_b};
            
            if (shift_amt >= 24) begin
                // Shifted too far, result is effectively zero
                mb = 0;
            end else if (shift_amt == 0) begin
                mb = mb_full;
            end else begin
                // Shift right by shift_amt
                mb = mb_full >> shift_amt;
                
                // Get the bits that were shifted out for rounding
                Bit#(24) shifted_out_mask = (1 << shift_amt) - 1;
                Bit#(24) shifted_out_bits = mb_full & shifted_out_mask;
                
                // Guard bit: MSB of shifted out bits (bit at position shift_amt-1)
                Bit#(1) guard = shifted_out_bits[shift_amt - 1];
                
                // Round bit: next bit after guard (if exists)
                Bit#(1) round_bit = (shift_amt > 1) ? shifted_out_bits[shift_amt - 2] : 1'b0;
                
                // Sticky bit: OR of all remaining bits
                Bit#(24) sticky_mask = (shift_amt > 2) ? ((1 << (shift_amt - 2)) - 1) : 0;
                Bit#(1) sticky = ((shifted_out_bits & sticky_mask) != 0) ? 1'b1 : 1'b0;
                
                // Round to nearest, ties to even logic
                // Round up if:
                // 1. Guard=1 AND (Round=1 OR Sticky=1) -> more than halfway
                // 2. Guard=1 AND Round=0 AND Sticky=0 AND LSB=1 -> exactly halfway, round to even
                Bit#(1) lsb = mb[0];  // LSB of result after shift
                Bit#(1) round_up = guard & ((round_bit | sticky) | lsb);
                
                mb = mb + zeroExtend(round_up);
            end
            
            exp_out = exp_a;
        end
        else if (exp_b > exp_a) begin
            Bit#(8) shift_amt = exp_b - exp_a;
            
            // Perform shift with rounding
            Bit#(24) ma_full = {1'b1, mantissa_a};
            
            if (shift_amt >= 24) begin
                ma = 0;
            end else if (shift_amt == 0) begin
                ma = ma_full;
            end else begin
                ma = ma_full >> shift_amt;
                
                // Get the bits that were shifted out for rounding
                Bit#(24) shifted_out_mask = (1 << shift_amt) - 1;
                Bit#(24) shifted_out_bits = ma_full & shifted_out_mask;
                
                // Guard bit
                Bit#(1) guard = shifted_out_bits[shift_amt - 1];
                
                // Round bit
                Bit#(1) round_bit = (shift_amt > 1) ? shifted_out_bits[shift_amt - 2] : 1'b0;
                
                // Sticky bit
                Bit#(24) sticky_mask = (shift_amt > 2) ? ((1 << (shift_amt - 2)) - 1) : 0;
                Bit#(1) sticky = ((shifted_out_bits & sticky_mask) != 0) ? 1'b1 : 1'b0;
                
                // Round to nearest, ties to even
                Bit#(1) lsb = ma[0];
                Bit#(1) round_up = guard & ((round_bit | sticky) | lsb);
                
                ma = ma + zeroExtend(round_up);
            end
            
            mb = {1'b1, mantissa_b};
            exp_out = exp_b;
        end
        else begin
            ma = {1'b1, mantissa_a};
            mb = {1'b1, mantissa_b};
            exp_out = exp_a;
        end
        
        // Extend 24-bit mantissas to 32-bits for KS adder
        Bit#(32) ma_ext = {8'b0, ma};
        Bit#(32) mb_ext = {8'b0, mb};
        
        // Add mantissas using 32-bit Kogge-Stone adder
        let adder_result <- ks_adder.add(ma_ext, mb_ext, 1'b0);
        match {.mant_sum, .cout} = adder_result;
        
        // mant_sum[24:0] contains the 25-bit result
        Bit#(25) mant_sum_25 = mant_sum[24:0];
        
        // Normalize: if bit 24 is set, shift right and increment exponent
        Bit#(23) mant_final = 0;
        Bit#(8) exp_final = 0;
        
        if (mant_sum_25[24] == 1'b1) begin
            // Overflow occurred, shift right and increment exponent
            // Apply rounding here too for the normalization shift
            Bit#(1) guard_norm = mant_sum_25[0];  // Bit being shifted out
            Bit#(23) shifted_mant = mant_sum_25[23:1];
            Bit#(1) lsb_norm = shifted_mant[0];
            
            // For ties to even: round up if guard=1 AND lsb=1
            Bit#(1) round_up_norm = guard_norm & lsb_norm;
            
            mant_final = shifted_mant + zeroExtend(round_up_norm);
            exp_final = exp_out + 1;   // i have to use a adder here
        end
        else begin
            // No overflow, use lower 23 bits
            mant_final = mant_sum_25[22:0];
            exp_final = exp_out;
        end
        
        // Combine result: sign bit = 1, exponent, mantissa
        Bit#(32) result = {1'b1, exp_final, mant_final};
        
        return result;
        
    endmethod
    
endmodule: mkFpAdder

endpackage: fp_adder
