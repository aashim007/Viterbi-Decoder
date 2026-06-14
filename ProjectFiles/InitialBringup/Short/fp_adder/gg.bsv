package gg;

interface Ifc_gg;
    method Bit#(1) gout (Bit#(1) g1, Bit#(1) p1, Bit#(1) p0);
endinterface: Ifc_gg

(*synthesize*)
module mkgg(Ifc_gg);
    method Bit#(1) gout (Bit#(1) g1, Bit#(1) p1, Bit#(1) p0);
        return g1 | (p1&p0);
    endmethod

endmodule: mkgg

endpackage: gg