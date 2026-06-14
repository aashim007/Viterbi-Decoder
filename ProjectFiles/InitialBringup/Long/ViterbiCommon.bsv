package ViterbiCommon;
  typedef Bit#(1)   NMAddr;
  typedef Bit#(10)  AMatrixAddr;
  typedef Bit#(10)  BMatrixAddr;
  typedef Bit#(10)  InputMatrixAddr;
  typedef Bit#(10)  OutputMatrixAddr;

  typedef Bit#(32)  Word;

  // Traceback memory
  // Constraint 3: Restricting BackTrace to 1K entries, ie 
  //               max possible input time-steps = 33
  //               since 1024/31 = 33
  typedef 31 MaxNoOfStates;
  typedef 33 MaxInputSeqLength;
  // typedef 1024 MaxInputSeqLength;
  typedef 6 TimeBits;
  typedef Bit#(10) BackTraceAddr; // 1K locations memory (33*31)
  // for 1024 :: typedef Bit#(15) BackTraceAddr; // Needs 32K locations memory (1024*31)

  // Memory Request and Response
  typedef struct {
      addr_t addr;
  } MemReq#(type addr_t) deriving(Bits, Eq);

  typedef struct {
      Word data;
  } MemResp deriving(Bits, Eq);

  // Memory Write Request
  typedef struct {
      addr_t addr;
      Word data;
  } MemWriteReq#(type addr_t) deriving(Bits, Eq);

endpackage : ViterbiCommon
