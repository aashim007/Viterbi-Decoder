package ks;

import gp::*;
import gg::*;
import Vector::*;

interface Ifc_ks;
    method ActionValue#(Tuple2#(Bit#(32), Bit#(1))) add(Bit#(32) a, Bit#(32) b, Bit#(1) cin);
endinterface: Ifc_ks

(* synthesize *)
module mkKs(Ifc_ks);
    
    // Instantiate gg and gp modules for each layer
    Vector#(31, Ifc_gg) gg_layer0 <- replicateM(mkgg);
    Vector#(31, Ifc_gp) gp_layer0 <- replicateM(mkgp);
    
    Vector#(30, Ifc_gg) gg_layer1 <- replicateM(mkgg);
    Vector#(30, Ifc_gp) gp_layer1 <- replicateM(mkgp);
    
    Vector#(28, Ifc_gg) gg_layer2 <- replicateM(mkgg);
    Vector#(28, Ifc_gp) gp_layer2 <- replicateM(mkgp);
    
    Vector#(24, Ifc_gg) gg_layer3 <- replicateM(mkgg);
    Vector#(24, Ifc_gp) gp_layer3 <- replicateM(mkgp);
    
    Vector#(16, Ifc_gg) gg_layer4 <- replicateM(mkgg);
    Vector#(16, Ifc_gp) gp_layer4 <- replicateM(mkgp);
    
    Vector#(31, Ifc_gg) gg_carry <- replicateM(mkgg);
    
    method ActionValue#(Tuple2#(Bit#(32), Bit#(1))) add(Bit#(32) a, Bit#(32) b, Bit#(1) cin);
        // Initial generate and propagate
        Bit#(32) g0 = a & b;
        Bit#(32) p0 = a ^ b;
        
        // Layer 0 (distance 1)
        Vector#(32, Bit#(1)) g1 = newVector();
        Vector#(32, Bit#(1)) p1 = newVector();
        g1[0] = g0[0];
        p1[0] = p0[0];
        
        for (Integer i = 1; i < 32; i = i + 1) begin
            g1[i] = gg_layer0[i-1].gout(g0[i], p0[i], g0[i-1]);
            p1[i] = gp_layer0[i-1].pout(p0[i], p0[i-1]);
        end
        
        // Layer 1 (distance 2)
        Vector#(32, Bit#(1)) g2 = newVector();
        Vector#(32, Bit#(1)) p2 = newVector();
        
        for (Integer i = 0; i < 2; i = i + 1) begin
            g2[i] = g1[i];
            p2[i] = p1[i];
        end
        
        for (Integer i = 2; i < 32; i = i + 1) begin
            g2[i] = gg_layer1[i-2].gout(g1[i], p1[i], g1[i-2]);
            p2[i] = gp_layer1[i-2].pout(p1[i], p1[i-2]);
        end
        
        // Layer 2 (distance 4)
        Vector#(32, Bit#(1)) g3 = newVector();
        Vector#(32, Bit#(1)) p3 = newVector();
        
        for (Integer i = 0; i < 4; i = i + 1) begin
            g3[i] = g2[i];
            p3[i] = p2[i];
        end
        
        for (Integer i = 4; i < 32; i = i + 1) begin
            g3[i] = gg_layer2[i-4].gout(g2[i], p2[i], g2[i-4]);
            p3[i] = gp_layer2[i-4].pout(p2[i], p2[i-4]);
        end
        
        // Layer 3 (distance 8)
        Vector#(32, Bit#(1)) g4 = newVector();
        Vector#(32, Bit#(1)) p4 = newVector();
        
        for (Integer i = 0; i < 8; i = i + 1) begin
            g4[i] = g3[i];
            p4[i] = p3[i];
        end
        
        for (Integer i = 8; i < 32; i = i + 1) begin
            g4[i] = gg_layer3[i-8].gout(g3[i], p3[i], g3[i-8]);
            p4[i] = gp_layer3[i-8].pout(p3[i], p3[i-8]);
        end
        
        // Layer 4 (distance 16) - NEW for 32-bit
        Vector#(32, Bit#(1)) g5 = newVector();
        Vector#(32, Bit#(1)) p5 = newVector();
        
        for (Integer i = 0; i < 16; i = i + 1) begin
            g5[i] = g4[i];
            p5[i] = p4[i];
        end
        
        for (Integer i = 16; i < 32; i = i + 1) begin
            g5[i] = gg_layer4[i-16].gout(g4[i], p4[i], g4[i-16]);
            p5[i] = gp_layer4[i-16].pout(p4[i], p4[i-16]);
        end
        
        // Carry computation
        Vector#(32, Bit#(1)) c = newVector();
        c[0] = cin;
        
        for (Integer i = 0; i < 31; i = i + 1) begin
            c[i+1] = gg_carry[i].gout(g5[i], p5[i], cin);
        end
        
        // Final sum and carry out
        Bit#(32) c_vec = pack(c);
        Bit#(32) sum = p0 ^ c_vec;
        Bit#(1) cout = g5[31] | (p5[31] & cin);
        
        return tuple2(sum, cout);
    endmethod
    
endmodule: mkKs

endpackage: ks
