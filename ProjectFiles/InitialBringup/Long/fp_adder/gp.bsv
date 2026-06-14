package gp;

interface Ifc_gp;
    method Bit#(1) pout (Bit#(1) p1, Bit#(1) p0);
endinterface: Ifc_gp

(*synthesize*)
module mkgp(Ifc_gp);
    method Bit#(1) pout (Bit#(1) p1, Bit#(1) p0);
        return (p1&p0);
    endmethod

endmodule: mkgp

endpackage: gp