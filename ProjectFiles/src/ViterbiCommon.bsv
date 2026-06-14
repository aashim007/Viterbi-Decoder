package ViterbiCommon;
  typedef Bit#(1)   NMAddr;
  typedef Bit#(10)  AMatrixAddr;
  typedef Bit#(10)  BMatrixAddr;
  typedef Bit#(10)  InputMatrixAddr;
  typedef Bit#(11)  OutputMatrixAddr;

  typedef Bit#(32)  Word;

  // Traceback memory
  // Constraint 3: Restricting BackTrace to 1K entries, ie 
  //               max possible input time-steps = 33
  //               since 1024/31 = 33
  typedef 31 MaxNoOfStates;
  typedef 31 MaxNoOfObservations;
  // Incorrect typedef 33 MaxInputSeqLength;
  typedef 1023 MaxExtMemoryAddress;
  typedef Bit#(10) BackTraceAddr; // 1K locations memory 

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

  //// BackTraceBuffer 
  //// Memory Read Response
  //typedef struct {
  //    Bit#(5) data;
  //} BTBMemResp deriving(Bits, Eq);

  //// Memory Write Request
  //typedef struct {
  //    addr_t addr;
  //    Bit#(5) data;
  //} BTBMemWriteReq#(type addr_t) deriving(Bits, Eq);


endpackage : ViterbiCommon
