package ks_adder;

import gg::*;
import gp::*;

interface Ifc_ks;
    method Bit#(16) Sum (Bit#(16) a, Bit#(16) b);
endinterface: Ifc_ks

module mkks(Ifc_ks);

endmodule

endpackage