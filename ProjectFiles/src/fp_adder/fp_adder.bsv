package fp_adder;

import Vector::*;

interface Ifc_fp_adder;
    // Added Tuple to pass error bit also
    method ActionValue#(Tuple2#(Bit#(32), Bit#(1))) add(Bit#(32) a, Bit#(32) b);
endinterface: Ifc_fp_adder

//function for 8 bit adder
function Tuple2#(Bit#(8), Bit#(1)) fa8_add(Bit#(8) a, Bit#(8) b, Bit#(1) cin);
    Bit#(8) sum_out = 0;
    Bit#(1) carry = cin;
    
    for (Integer i = 0; i < 8; i = i + 1) begin
        sum_out[i] = a[i] ^ b[i] ^ carry;
        carry = (a[i] & b[i]) | (carry & (a[i] ^ b[i]));
    end
    
    return tuple2(sum_out, carry);
endfunction

//for 32 bit brent kung adder is used
function Tuple2#(Bit#(32), Bit#(1)) bk32_add(Bit#(32) a, Bit#(32) b, Bit#(1) cin);
    // gg: g = g1 | (p1 & g0)
    function Bit#(1) gg(Bit#(1) g1, Bit#(1) p1, Bit#(1) g0);
        return g1 | (p1 & g0);
    endfunction
    
    // gp: p = p1 & p0
    function Bit#(1) gp(Bit#(1) p1, Bit#(1) p0);
        return p1 & p0;
    endfunction
    
    //0th layer
    Bit#(32) g0 = a & b;
    Bit#(32) p0 = a ^ b;
    
    //1st layer
    Vector#(32, Bit#(1)) g1 = newVector();
    Vector#(32, Bit#(1)) p1 = newVector();
    
    g1[0] = g0[0];
    p1[0] = p0[0];
    
    for (Integer i = 1; i < 32; i = i + 2) begin
        g1[i] = gg(g0[i], p0[i], g0[i-1]);
        p1[i] = gp(p0[i], p0[i-1]);
        if (i < 31) begin
            g1[i+1] = g0[i+1];
            p1[i+1] = p0[i+1];
        end
    end
    
    //2nd layer
    Vector#(32, Bit#(1)) g2 = newVector();
    Vector#(32, Bit#(1)) p2 = newVector();
    
    for (Integer i = 0; i < 32; i = i + 1) begin
        if ((i % 4 == 3) && (i >= 3)) begin
            g2[i] = gg(g1[i], p1[i], g1[i-2]);
            p2[i] = gp(p1[i], p1[i-2]);
        end else begin
            g2[i] = g1[i];
            p2[i] = p1[i];
        end
    end
    
    //3rd layer
    Vector#(32, Bit#(1)) g3 = newVector();
    Vector#(32, Bit#(1)) p3 = newVector();
    
    for (Integer i = 0; i < 32; i = i + 1) begin
        if ((i % 8 == 7) && (i >= 7)) begin
            g3[i] = gg(g2[i], p2[i], g2[i-4]);
            p3[i] = gp(p2[i], p2[i-4]);
        end else begin
            g3[i] = g2[i];
            p3[i] = p2[i];
        end
    end
    
    //4th layer
    Vector#(32, Bit#(1)) g4 = newVector();
    Vector#(32, Bit#(1)) p4 = newVector();
    
    for (Integer i = 0; i < 32; i = i + 1) begin
        if ((i % 16 == 15) && (i >= 15)) begin
            g4[i] = gg(g3[i], p3[i], g3[i-8]);
            p4[i] = gp(p3[i], p3[i-8]);
        end else begin
            g4[i] = g3[i];
            p4[i] = p3[i];
        end
    end
    
    //final stage
    Vector#(32, Bit#(1)) g5 = newVector();
    Vector#(32, Bit#(1)) p5 = newVector();
    
    for (Integer i = 0; i < 32; i = i + 1) begin
        if (i == 31) begin
            g5[i] = gg(g4[i], p4[i], g4[15]);
            p5[i] = gp(p4[i], p4[15]);
        end else begin
            g5[i] = g4[i];
            p5[i] = p4[i];
        end
    end
    
    // carry calculations
    Vector#(32, Bit#(1)) c = newVector();
    c[0] = cin;
    
    c[1]  = gg(g0[0],  p0[0],  c[0]);
    c[2]  = gg(g1[1],  p1[1],  c[0]);
    c[4]  = gg(g2[3],  p2[3],  c[0]);
    c[8]  = gg(g3[7],  p3[7],  c[0]);
    c[16] = gg(g4[15], p4[15], c[0]);
    
    c[3]  = gg(g0[2],   p0[2],   c[2]);
    c[5]  = gg(g0[4],   p0[4],   c[4]);
    c[6]  = gg(g1[5],   p1[5],   c[4]);
    c[7]  = gg(g0[6],   p0[6],   c[6]);
    c[9]  = gg(g0[8],   p0[8],   c[8]);
    c[10] = gg(g1[9],  p1[9],   c[8]);
    c[11] = gg(g0[10], p0[10],  c[10]);
    c[12] = gg(g2[11], p2[11],  c[8]);
    c[13] = gg(g0[12], p0[12],  c[12]);
    c[14] = gg(g1[13], p1[13],  c[12]);
    c[15] = gg(g0[14], p0[14],  c[14]);
    c[17] = gg(g0[16], p0[16],  c[16]);
    c[18] = gg(g1[17], p1[17],  c[16]);
    c[19] = gg(g0[18], p0[18],  c[18]);
    c[20] = gg(g2[19], p2[19],  c[16]);
    c[21] = gg(g0[20], p0[20],  c[20]);
    c[22] = gg(g1[21], p1[21],  c[20]);
    c[23] = gg(g0[22], p0[22],  c[22]);
    c[24] = gg(g3[23], p3[23],  c[16]);
    c[25] = gg(g0[24], p0[24],  c[24]);
    c[26] = gg(g1[25], p1[25],  c[24]);
    c[27] = gg(g0[26], p0[26],  c[26]);
    c[28] = gg(g2[27], p2[27],  c[24]);
    c[29] = gg(g0[28], p0[28],  c[28]);
    c[30] = gg(g1[29], p1[29],  c[28]);
    c[31] = gg(g0[30], p0[30],  c[30]);
    
    Bit#(1) cout = gg(g5[31], p5[31], c[0]);
    
    Bit#(32) c_vec = pack(c);
    Bit#(32) sum = p0 ^ c_vec;
    
    return tuple2(sum, cout);
endfunction

(* synthesize *)
module mkFpAdder(Ifc_fp_adder);
    
    method ActionValue#(Tuple2#(Bit#(32), Bit#(1))) add(Bit#(32) a, Bit#(32) b);
        
        //exponents and mantissas are separated
        Bit#(8) exp_a = a[30:23];
        Bit#(23) mantissa_a = a[22:0];
        Bit#(8) exp_b = b[30:23];
        Bit#(23) mantissa_b = b[22:0];
        
        // Check for NaN or Infinity
        Bit#(1) fperror = 0;
        if (exp_a == 8'hFF || exp_b == 8'hFF) begin
            fperror = 1;
        end
        
        //cariables for aligning mantissa and exponents
        Bit#(24) ma = 0;
        Bit#(24) mb = 0;
        Bit#(3) grs_a = 3'b000;  
        Bit#(3) grs_b = 3'b000;  
        Bit#(8) exp_out = 0;
        
        Bit#(32) result = 32'h00000000;
        
        if (fperror == 0) begin
            //checking the difference between exponents and which is bigger
            if (exp_a > exp_b) begin
                ma = {1'b1, mantissa_a};
                grs_a = 3'b000;
                
                //Bit#(8) shift_amt = exp_a - exp_b;
                match {.shift_amt, .sub_cout} = fa8_add(exp_a, ~exp_b, 1'b1);

                
                Bit#(24) mb_full = {1'b1, mantissa_b};
                
                // sticking the result to 0 if shifted one is too large
                if (shift_amt>= 24) begin
                    mb = 0;
                    grs_b = (mb_full != 0) ? 3'b001:3'b000;
                end 
                else if (shift_amt == 0) begin
                    mb = mb_full;
                    grs_b = 3'b000;
                end 
                // a is greater so b will be right shifted
                else begin
                    mb = mb_full>>shift_amt;
                    
                    //for grs storing the shifted bits
                    Bit#(32) shift_left_result = {8'b0, (1 << shift_amt)};
                    Bit#(32) one_ext = 32'd1;
                    match {.mask_result, .mask_cout} = bk32_add(shift_left_result, ~one_ext, 1'b1);
                    Bit#(24) shifted_out_mask = mask_result[23:0];      // adder
                    
                    
                    Bit#(24) shifted_out_bits = mb_full & shifted_out_mask;
                    
                    //msb of shifted bits
                    Bit#(1) guard = shifted_out_bits[shift_amt - 1];
                    
                    //Round bit: next bit after guard
                    Bit#(1) round_bit = (shift_amt > 1) ? shifted_out_bits[shift_amt - 2] : 1'b0;
                    
                    //sticky bit
                    Bit#(24) sticky_mask = (shift_amt > 2) ? ((1 << (shift_amt - 2)) - 1) : 0;
                    Bit#(1) sticky = ((shifted_out_bits & sticky_mask) != 0) ? 1'b1 : 1'b0;
                    
                    //grs should not be rounded here
                    grs_b = {guard, round_bit, sticky};
                end
                
                exp_out = exp_a;
            end

            // if b>a then same thing 
            else if (exp_b>exp_a) begin
                //Bit#(8) shift_amt = exp_b - exp_a;
                match {.shift_amt, .sub_cout} = fa8_add(exp_b, ~exp_a, 1'b1);

                
                Bit#(24) ma_full = {1'b1, mantissa_a};
                
                if (shift_amt >= 24) begin
                    ma = 0;
                    grs_a = (ma_full != 0) ? 3'b001 : 3'b000;
                end 
                else if (shift_amt == 0) begin
                    ma = ma_full;
                    grs_a = 3'b000;
                end 
                else begin
                    ma = ma_full >> shift_amt;
                    
                    Bit#(24) shifted_out_mask = (1 << shift_amt) - 1;
                    Bit#(24) shifted_out_bits = ma_full & shifted_out_mask;
                    
                    Bit#(1) guard = shifted_out_bits[shift_amt - 1];
                    
                    Bit#(1) round_bit = (shift_amt > 1) ? shifted_out_bits[shift_amt - 2] : 1'b0;

                    Bit#(24) sticky_mask = (shift_amt > 2) ? ((1 << (shift_amt - 2)) - 1) : 0;
                    Bit#(1) sticky = ((shifted_out_bits & sticky_mask) != 0) ? 1'b1 : 1'b0;
                    
                    grs_a = {guard, round_bit, sticky};
                end
                
                mb = {1'b1, mantissa_b};
                grs_b = 3'b000;
                exp_out = exp_b;
            end

            // if both exponents are same 
            else begin
                ma = {1'b1, mantissa_a};
                mb = {1'b1, mantissa_b};
                grs_a = 3'b000;
                grs_b = 3'b000;
                exp_out = exp_a;
            end
            
            //my bk adder is 32 bit so extending my mantissas 
            Bit#(32) ma_ext = {8'b0, ma};
            Bit#(32) mb_ext = {8'b0, mb};
            
            match {.mant_sum, .cout} = bk32_add(ma_ext, mb_ext, 1'b0);
            
            //grs addition
            //grs addition
            match {.grs_sum_8, .grs_cout} = fa8_add({5'b0, grs_a}, {5'b0, grs_b}, 1'b0);
            Bit#(3) grs_result = grs_sum_8[2:0];
            Bit#(1) grs_carry = grs_sum_8[3];

            
            //carry propagation
            //carry propagation
            Bit#(32) mant_sum_ext = {7'b0, mant_sum[24:0]};
            Bit#(32) grs_carry_ext = {31'b0, grs_carry};
            match {.mant_sum_final, .cout2} = bk32_add(mant_sum_ext, grs_carry_ext, 1'b0);
            Bit#(25) mant_sum_25 = mant_sum_final[24:0];

            //Bit#(25) mant_sum_25 = mant_sum[24:0] + zeroExtend(grs_carry);
            
            
            //normalization
            Bit#(24) mant_prenorm = 0;
            Bit#(3) grs_final = 0;
            Bit#(8) exp_prenorm = 0;
            
            if (mant_sum_25[24] == 1'b1) begin
                // for overflow shift right
                mant_prenorm = mant_sum_25[24:1];

                grs_final = {mant_sum_25[0], grs_result[2:1]};
                
                grs_final[0] = grs_result[0] | grs_result[1];
                
                match {.exp_inc, .exp_cout} = fa8_add(exp_out, 8'd1, 1'b0);
                exp_prenorm = exp_inc;

            end
            //no overflow case
            else begin
                mant_prenorm = mant_sum_25[23:0];
                grs_final = grs_result;
                exp_prenorm = exp_out;
            end
            
            //rounding here
            Bit#(1) guard_rounding = grs_final[2];
            Bit#(1) round_bit_rounding = grs_final[1];
            Bit#(1) sticky_rounding = grs_final[0];
            Bit#(1) lsb = mant_prenorm[0];
            
            //nearest round, tied to even
            Bit#(1) round_up = 0;
            if (guard_rounding == 1'b1) begin
                if (round_bit_rounding == 1'b1 || sticky_rounding == 1'b1) begin
                    round_up = 1'b1;
                end else begin
                    round_up = lsb;
                end
            end
            
            //Bit#(25) mant_rounded = zeroExtend(mant_prenorm) + zeroExtend(round_up);
            Bit#(32) mant_prenorm_ext2 = {8'b0, mant_prenorm};
            Bit#(32) round_ext2 = {31'b0, round_up};
            match {.mant_rounded_temp, .cout4} = bk32_add(mant_prenorm_ext2, round_ext2, 1'b0);
            Bit#(25) mant_rounded = mant_rounded_temp[24:0];

            
            Bit#(23) mant_final = 0;
            Bit#(8) exp_final = 0;
            
            //checking overflow after rounding
            if (mant_rounded[24] == 1'b1) begin
                mant_final = mant_rounded[23:1];
                
                match {.exp_inc2, .exp_cout2} = fa8_add(exp_prenorm, 8'd1, 1'b0);
                exp_final = exp_inc2;

            end
            //no overflow
            else begin
                mant_final = mant_rounded[22:0];
                exp_final = exp_prenorm;
            end
            
            //MSB is always 1 as we only deal with negative numbers 
            result = {1'b1, exp_final, mant_final};
        end
        
        return tuple2(result, fperror);
        
    endmethod
    
endmodule: mkFpAdder

endpackage: fp_adder
