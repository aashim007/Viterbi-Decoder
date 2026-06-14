// RTL for Viterbi Decoder
package ViterbiDecoder;
  import ViterbiCommon::*;
  import RegFile::*;
  import FIFO::*;
  import Vector::*;
  import fp_adder::*;
 
  // Simple interface with start and done
interface ViterbiDecoderIfc;
    // Control
    method Action start();
method Bool done();
    
    // Errors
    method Bool inputError();
    method Bool fpError();

    // RegFile Access (2 read ports, 1 write port for each RegFile)
    method ActionValue#(MemReq#(NMAddr)) readReq_NM1();
    method Action readResp_NM1(MemResp resp);
    method ActionValue#(MemReq#(NMAddr)) readReq_NM2();
    method Action readResp_NM2(MemResp resp);

    method ActionValue#(MemReq#(AMatrixAddr)) readReq_A1();
    method Action readResp_A1(MemResp resp);
    // Removing unused ports :: method ActionValue#(MemReq#(AMatrixAddr)) readReq_A2();
    // Removing unused ports :: method Action readResp_A2(MemResp resp);

    method ActionValue#(MemReq#(BMatrixAddr)) readReq_B1();
    method Action readResp_B1(MemResp resp);
    // Removing unused ports :: method ActionValue#(MemReq#(BMatrixAddr)) readReq_B2();
    // Removing unused ports :: method Action readResp_B2(MemResp resp);

    method ActionValue#(MemReq#(InputMatrixAddr)) readReq_Input1();
    method Action readResp_Input1(MemResp resp);
    // Removing unused ports :: method ActionValue#(MemReq#(InputMatrixAddr)) readReq_Input2();
    // Removing unused ports :: method Action readResp_Input2(MemResp resp);
    
    method ActionValue#(MemWriteReq#(OutputMatrixAddr)) writeReq_Output();

    method ActionValue#(MemReq#(BackTraceAddr)) readReq_BTB1();
    method Action readResp_BTB1(MemResp resp);
    // Removing unused ports :: method ActionValue#(MemReq#(BackTraceAddr)) readReq_BTB2();
    // Removing unused ports :: method Action readResp_BTB2(MemResp resp);
    method ActionValue#(MemWriteReq#(BackTraceAddr)) writeReq_BTB();

    // Removed :: // VCurr memory interface
    // Removed :: method ActionValue#(MemReq#(VRegAddr)) readReq_VCurr();
    // Removed :: method Action readResp_VCurr(MemResp resp);
    // Removed :: method ActionValue#(MemWriteReq#(VRegAddr)) writeReq_VCurr();

    // Removed :: // VPrev memory interface  
    // Removed :: method ActionValue#(MemReq#(VRegAddr)) readReq_VPrev();
    // Removed :: method Action readResp_VPrev(MemResp resp);
    // Removed :: method ActionValue#(MemWriteReq#(VRegAddr)) writeReq_VPrev();


  endinterface : ViterbiDecoderIfc

  // FSM States
  typedef enum {
    // Start States
    IDLE, 
    START,
    
    // Get N & M
    INIT_GET_NM, 
    DONE_GET_NM, 
    
    // V1 Calculation
    V1_CALC_START, 
    GET_INPUT_V1,
    INIT_COMPUTE_V1,
    LOOP_V1_INIT_GET_AB, 
    LOOP_V1_DONE_GET_AB,
    LOOP_V1_INIT_FP_ADD, 
    LOOP_V1_DONE_FP_ADD,
    LOOP_V1_NEXT_STATE, 
    // Not required :: LOOP_V1_DONE_ADD,
    // Not required :: LOOP_V1_OUTPUT,
    // Not required :: LOOP_V1_NEXT,
    V1_CALC_END,
    
    // Vt Recursive Calculation (iterate till end, ie, FF)
    VT_CALC_START,
    VT_GET_INPUT,
    VT_INIT_J_LOOP, // j loop from spec
    VT_INIT_I_LOOP, // i loop from spec
    VT_GET_PREV_PROB,
    VT_INIT_GET_AB,
    VT_DONE_GET_AB,
    VT_INIT_FP_ADD, // fires prob + A
    // Optimised for single-B addition ::VT_PROC_FP_ADD, // fires intermediate + B
    VT_DONE_FP_ADD, 
    VT_LOOP_I_LOOP, // Optimised for single-B addition
    // Optimised :: VT_CALC_MAX_PROB,
    // Optimised :: VT_DONE_MAX_PROB, // both sums done
    // Optimised :: VT_INIT_SAVE_STATE,
    VT_SAVE_STATE,
    VT_GET_B_AND_ADD, // Optimised for single-B addition
    VT_ADD_B_TO_MAX,  // Optimised for single-B addition
    VT_STORE_RESULT,  // Optimised for single-B addition
    VT_STORE_BTB,
    VT_LOOP_J_LOOP,
    
    // Optimised :: Min reduction
    VT_MIN_INIT,
    VT_MIN_READ,
    VT_MIN_WAIT,
    VT_MIN_DONE,
    
    // added these for vcurr and vprev
    // Memory access states for vCurr/vPrev
    V1_WRITE_VCURR,
    VT_WRITE_VCURR,
    VT_READ_VPREV,
    VT_READ_VPREV_WAIT,
    SWAP_INIT,
    SWAP_READ_VCURR,
    SWAP_WRITE_VPREV,

    // Traceback & Write output probable state
    TRACEBACK_CALC_START,
    TRACEBACK_LOOP_START,
    TRACEBACK_LOOP_EXEC,
    TRACEBACK_WRITE_FINAL_PROB,
    
    // Finish States
    WRITE_FF_MARKER,
    DONE,
    INPUT_ERROR,
    FP_ERROR

    
  } ViterbiState deriving (Bits, Eq, FShow);

  (*synthesize*)
  module mkViterbiDecoder(ViterbiDecoderIfc);
  //---------------------------------------------------
  
  //==========================
  // Internal Registers 
  //--------------------------
  // Control 
  Reg#(Bool) rg_start     <- mkReg(False);
  Reg#(Bool) rg_done      <- mkReg(False);
 
  // Error
  Reg#(Bool) rg_input_err <- mkReg(False);
  Reg#(Bool) rg_fp_err    <- mkReg(False);

  // Memory Interface
  FIFO#(MemReq#(NMAddr)) readReqFIFO_NM1   <- mkFIFO1;
  FIFO#(MemResp)         readRespFIFO_NM1  <- mkFIFO1;
  FIFO#(MemReq#(NMAddr)) readReqFIFO_NM2   <- mkFIFO1;
  FIFO#(MemResp)         readRespFIFO_NM2  <- mkFIFO1;
  
  FIFO#(MemReq#(AMatrixAddr))  readReqFIFO_A1   <- mkFIFO1;
  FIFO#(MemResp)               readRespFIFO_A1  <- mkFIFO1;
  // Unused FIFO#(MemReq#(AMatrixAddr))  readReqFIFO_A2   <- mkFIFO1;
  // Unused FIFO#(MemResp)               readRespFIFO_A2  <- mkFIFO1;
  
  FIFO#(MemReq#(BMatrixAddr))  readReqFIFO_B1   <- mkFIFO1;
  FIFO#(MemResp)               readRespFIFO_B1  <- mkFIFO1;
  // Unused FIFO#(MemReq#(BMatrixAddr))  readReqFIFO_B2   <- mkFIFO1;
  // Unused FIFO#(MemResp)               readRespFIFO_B2  <- mkFIFO1;
  
  FIFO#(MemReq#(InputMatrixAddr))  readReqFIFO_Input1   <- mkFIFO1;
  FIFO#(MemResp)                   readRespFIFO_Input1  <- mkFIFO1;
  // Unused FIFO#(MemReq#(InputMatrixAddr))  readReqFIFO_Input2   <- mkFIFO1;
  // Unused FIFO#(MemResp)                   readRespFIFO_Input2  <- mkFIFO1;

  FIFO#(MemWriteReq#(OutputMatrixAddr)) writeReqFIFO_Output <- mkFIFO1;
  
  FIFO#(MemReq#(BackTraceAddr))  readReqFIFO_BTB1   <- mkFIFO1;
  FIFO#(MemResp)              readRespFIFO_BTB1  <- mkFIFO1;
  FIFO#(MemWriteReq#(BackTraceAddr)) writeReqFIFO_BTB <- mkFIFO1;

  // adding these for vcurrreg and vprevreg
  // VCurr and VPrev memory interfaces
  // FIFO#(MemReq#(VRegAddr)) readReqFIFO_VCurr <- mkFIFO1;
  // FIFO#(MemResp) readRespFIFO_VCurr <- mkFIFO1;
  // FIFO#(MemWriteReq#(VRegAddr)) writeReqFIFO_VCurr <- mkFIFO1;

  // FIFO#(MemReq#(VRegAddr)) readReqFIFO_VPrev <- mkFIFO1;
  // FIFO#(MemResp) readRespFIFO_VPrev <- mkFIFO1;
  // FIFO#(MemWriteReq#(VRegAddr)) writeReqFIFO_VPrev <- mkFIFO1;    //till here

  Reg#(Vector#(32, Word)) vCurrSnapshot <- mkReg(replicate(32'hFFFFFFFF));
  Reg#(Bit#(5)) snapshotIndex <- mkReg(0);

  // FSM
  Reg#(ViterbiState) currState <- mkReg(IDLE);
  
  Reg#(NMAddr) nIndex <- mkReg(0);
  Reg#(NMAddr) mIndex <- mkReg(1);
  // Using variables for immediate assignment :: Reg#(AMatrixAddr) aIndex <- mkReg(0);
  // Using variables for immediate assignment :: Reg#(BMatrixAddr) bIndex <- mkReg(0);
  Reg#(InputMatrixAddr) inputIndex <- mkReg(0);
  Reg#(OutputMatrixAddr) outputOffset <- mkReg(0);

  Reg#(Word) nValue <- mkReg(0);
  Reg#(Word) mValue <- mkReg(0);
  Reg#(Word) aValue <- mkReg(0);
  Reg#(Word) bValue <- mkReg(0);
  Reg#(Word) inputValue <- mkReg(0);
  Reg#(Word) outputValue <- mkReg(0);

  Reg#(BackTraceAddr) maxInputSeqLength <- mkReg(0);

  // removing these for taking  them outside
  // Vector#(32, Reg#(Bit#(32))) vCurrReg <- replicateM(mkReg(0));
  // Vector#(32, Reg#(Bit#(32))) vPrevReg <- replicateM(mkReg(0));

  Reg#(Bit#(5)) stateIndex <- mkReg(0);
  Reg#(Bit#(5)) stateCount <- mkReg(0);
  Reg#(BackTraceAddr) timeStep <- mkReg(0);
  Reg#(Bit#(5)) prevStateIndex <- mkReg(0);
  Reg#(Word) maxProb <- mkReg(32'hFFFFFFFF);
  // !!!! Reg#(Word) maxProb <- mkReg(0);
  // Reg#(Word) currProb <- mkReg(0);
  Reg#(Word) prevProb<- mkReg(0);
  Reg#(Bit#(5)) bestPrevState <- mkReg(0);
  Reg#(Word) finalMaxProb <- mkReg(0);
  Reg#(Bit#(5)) bestFinalState <- mkReg(0);


  // TraceBack
  // Huge File requirement to store 1024*31*5 bits
  // maxnumberofobs * maxnumberofstates * sizeofstate
  // Moving outside :: RegFile#(BackTraceAddr, Bit#(5)) backTraceBuffer <- mkRegFile(0,1023); // 33*31 = 1023
  // for 1024 :: RegFile#(BackTraceAddr, Bit#(5)) backTraceBuffer <- mkRegFile(0,31743); // 1024*31 = 31744
  Reg#(BackTraceAddr) traceBackTime <- mkReg(0); // Very poetic variable.
  Reg#(Bit#(5)) currTraceState <- mkReg(0);

  Reg#(BackTraceAddr) baseAddrVCurr <- mkReg(0);
  Reg#(BackTraceAddr) baseAddrVPrev <- mkReg(0);

  // FP Adder
  Ifc_fp_adder fpAdder1 <- mkFpAdder;

  Reg#(Word) fpAddResult1 <- mkReg(0);

    // added For sequential min-finding
  Reg#(Bit#(5)) minIdx <- mkReg(0);               // Loop counter
  Reg#(Word) bestMin <- mkReg(32'hFFFFFFFF);      // Current minimum
  Reg#(Bit#(5)) bestMinIdx <- mkReg(0);           // Index of minimum

  //=================
  // Functions
  //-----------------
  function Bool validateV1Input(Word inputWord, Word maxValue);
    return (inputWord != 32'hFFFFFFFF) &&
           (inputWord != 32'h00000000) &&
           (inputWord <= maxValue);
  endfunction : validateV1Input

  function Bool validateVtInput(Word inputWord, Word maxValue);
    return (inputWord >= 1) && (inputWord <= maxValue);
  endfunction : validateVtInput

  function BackTraceAddr getBackTraceAddr(BackTraceAddr time_step, Bit#(5) curr_state, Word max_state); 
    // Backtrace 2-D array BTB[time][state], indexing into row-major
    BackTraceAddr time_step_ext  = zeroExtend(time_step);
    BackTraceAddr curr_state_ext = zeroExtend(curr_state);
    BackTraceAddr max_state_ext = truncate(max_state);
    return ((time_step_ext * max_state_ext) + (curr_state_ext - 1));
  endfunction : getBackTraceAddr

  function Bool validateN(Word value);
    // Check for values > 31, ie bits 31 to 5 should be 0
    // return ((value & 32'hFFFFFF80) == 32'h00000000);
    return ((value != 0) && (value <= (fromInteger(valueOf(MaxNoOfStates)))));
    // return (value < 32);
  endfunction : validateN

  function Bool validateM(Word value);
    return ((value != 0) && (value <= (fromInteger(valueOf(MaxNoOfObservations)))));
  endfunction : validateM

  function Bool validateSeqLength(BackTraceAddr value);
    return ((value != 0) && (value <= (maxInputSeqLength)));
  endfunction : validateSeqLength

  function BackTraceAddr calculateMaxInputSeqLength(Word maxStates);
    // Truncate maxStates to 5 bits
    BackTraceAddr maxStates_trunc = truncate(maxStates);
    // denominator-0 check
    if (maxStates_trunc == 0) begin
      return 0;
    end else begin
      BackTraceAddr maxInputSeqLen_calc = (((fromInteger(valueOf(MaxExtMemoryAddress))) + 1 - (2 * maxStates_trunc)) / (maxStates_trunc));
      return maxInputSeqLen_calc;
    end
  endfunction : calculateMaxInputSeqLength

  function BackTraceAddr calcVCurrAddr(Word nVal);
    return (fromInteger(valueOf(MaxExtMemoryAddress)) - (2 * truncate(nVal)) + 1);
  endfunction : calcVCurrAddr

    function BackTraceAddr calcVPrevAddr(Word nVal);
    return (fromInteger(valueOf(MaxExtMemoryAddress)) - truncate(nVal) + 1);
  endfunction : calcVPrevAddr

  //==========================
  // Rules
  //--------------------------
  // FSM Implementation
  
  // Idle State
  rule rl_IDLE(rg_start && (currState == IDLE));
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    currState <= START;
    rg_done <= False;
  endrule : rl_IDLE

  rule rl_START(currState == START);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    currState <= INIT_GET_NM;
  endrule : rl_START

  rule rl_INIT_GET_NM(currState == INIT_GET_NM);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    readReqFIFO_NM1.enq(MemReq{addr:nIndex});
    readReqFIFO_NM2.enq(MemReq{addr:mIndex});
    $display("[DUT] Time=%0t: Requesting N & M", $time);
    currState <= DONE_GET_NM;
  endrule : rl_INIT_GET_NM

  rule rl_DONE_GET_NM(currState == DONE_GET_NM);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    let respN = readRespFIFO_NM1.first;
    readRespFIFO_NM1.deq;
    nValue <= respN.data;
    // nValue <= unpack(truncate(respN.data));
    $display("[DUT] Time=%0t: Received N = %d", $time, respN.data);
    let respM = readRespFIFO_NM2.first;
    readRespFIFO_NM2.deq;
    mValue <= respM.data;
    // mValue <= unpack(truncate(respM.data));
    $display("[DUT] Time=%0t: Received M = %d", $time, respM.data);

    // Setting maxInputSeqLength
    maxInputSeqLength <= calculateMaxInputSeqLength(respN.data);

    // Setting Base address for VCurr and VPrev access
    baseAddrVCurr <= calcVCurrAddr(respN.data);
    baseAddrVPrev <= calcVPrevAddr(respN.data);

    // Negative :: Additional check added for N & M values
    let isvalidN = validateN(respN.data);
    let isvalidM = validateM(respM.data);
    if (! (isvalidN && isvalidM)) begin
      $display("[DUT][ERROR] Time=%0t: Received illegal N/M", $time);
      currState <= INPUT_ERROR;
    end else begin
      currState <= V1_CALC_START;
    end
  endrule : rl_DONE_GET_NM

  rule rl_V1_CALC_START(currState == V1_CALC_START);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    // Issue request for input
    readReqFIFO_Input1.enq(MemReq{addr:inputIndex});
    $display("[DUT] Time=%0t: Requesting Input-1", $time);
    currState <= GET_INPUT_V1;
  endrule : rl_V1_CALC_START

  rule rl_GET_INPUT_V1(currState == GET_INPUT_V1);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    let respInput = readRespFIFO_Input1.first;
    readRespFIFO_Input1.deq;
    if (respInput.data == 32'h00000000) begin
      $display("DEBUG : [DUT] Time=%0t: EOF detected. Going to DONE State!", $time);
      // Not required :: // Write FFFF to mark start of EOF
      // Not required :: writeReqFIFO_Output.enq(MemWriteReq{addr: outputOffset,
      // Not required ::                                     data: 32'hFFFFFFFF});

      // Not required :: outputOffset <= outputOffset + 1;
      currState <= DONE;
    end else begin
      let isValidinputV1 = validateV1Input(respInput.data, mValue);
      // For V1, do input validation here
      if (!isValidinputV1) begin
        $display("[DUT][ERROR] Time=%0t: Received illegal input for V1", $time);
        currState <= INPUT_ERROR;
        rg_input_err <= True;
      end else begin
        inputValue <= respInput.data;
        $display("[DUT] Time=%0t: Received Input-1 = %d", $time, respInput.data);
        currState <= INIT_COMPUTE_V1;
      end 
    end
  endrule : rl_GET_INPUT_V1

  rule rl_INIT_COMPUTE_V1(currState == INIT_COMPUTE_V1);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    $display("[DUT] Time=%0t: Starting V1 Computation for N=%d states", $time, nValue);
    stateIndex <= 1;
    stateCount <= truncate(nValue); // For comparison
    timeStep <= 0;
    currState <= LOOP_V1_INIT_GET_AB;
  endrule : rl_INIT_COMPUTE_V1

  rule rl_LOOP_V1_INIT_GET_AB(currState == LOOP_V1_INIT_GET_AB);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    $display("[DUT] Time=%0t: Computing V1[%d]", $time, stateIndex);

    // Calcualte address for A[0][state]
    // aIndex = 0 * N + (stateIndex - 1) for initial probability
    AMatrixAddr aIndex = zeroExtend(pack(stateIndex)) - 1; // zeroExtend because aIndex is 10 bits, stateIndex is 5 -> this is req for first state

    // Calcualte address for B[state][input]
    // bIndex = (state-1)*M + (input - 1)
    //Extension similar to A
    Bit#(10) stateIndex_ext = zeroExtend(pack(stateIndex));
    Bit#(10) inputValue_ext = truncate(pack(inputValue));
    Bit#(10) mValue_ext = truncate(pack(mValue));
    // BMatrixAddr bIndex = truncate((pack(stateIndex) - 1) * mValue + (inputValue - 1));
    BMatrixAddr bIndex = (stateIndex_ext - 1) * mValue_ext + (inputValue_ext - 1);

    // Issue both A and B requests
    // Improvement: Use 2x read ports for A and B in parallel, compute 2 states
    readReqFIFO_A1.enq(MemReq{addr:aIndex});
    readReqFIFO_B1.enq(MemReq{addr:bIndex});
    
    $display("[DUT] Time=%0t: Requesting A[0][%d] @ addr=%d", $time, stateIndex, aIndex);
    $display("[DUT] Time=%0t: Requesting B[%d][%d] @ addr=%d", $time, stateIndex, inputValue, bIndex);
    currState <= LOOP_V1_DONE_GET_AB;
  endrule : rl_LOOP_V1_INIT_GET_AB

  rule rl_LOOP_V1_DONE_GET_AB(currState == LOOP_V1_DONE_GET_AB);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    // A response
    let respA = readRespFIFO_A1.first;
    readRespFIFO_A1.deq;
    aValue <= respA.data;
    $display("[DUT] Time=%0t: Received A[0][%d] = %h (log prob)", $time, stateIndex, respA.data);
    // B response
    let respB = readRespFIFO_B1.first;
    readRespFIFO_B1.deq;
    bValue <= respB.data;
    $display("[DUT] Time=%0t: Received B[%d][%d] = %h (log prob)", $time, stateIndex, inputValue, respB.data);
    // TODO: Validate A and B probabilities
    // If positive, move to input error
    // Using msb function that BSV provides
    if (msb(respA.data) == 1'b0 || msb(respB.data) == 1'b0) begin
      $display("[DUT][ERROR] Time=%0t: Invalid probability", $time);
      currState <= INPUT_ERROR;
      rg_input_err <= True;
    end else begin
      currState <= LOOP_V1_INIT_FP_ADD;
    end
  endrule : rl_LOOP_V1_DONE_GET_AB

  rule rl_LOOP_V1_INIT_FP_ADD(currState == LOOP_V1_INIT_FP_ADD);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    // Calculate V1(j)
    let addResult <- fpAdder1.add(aValue, bValue);
    // Using match to extract data from Tuple
    match {.sum, .error} = addResult;
    fpAddResult1 <= sum;
    if (error == 1'b1) begin
        $display("[DUT][ERROR] Time=%0t: FP Error from FP Adder for sum = %h", $time, sum);
        rg_fp_err <= True;
        currState <= FP_ERROR;
    end
    else begin
        $display("[DUT] Time=%0t: Computing V1[%d] = A + B", $time, stateIndex);
        currState <= LOOP_V1_DONE_FP_ADD;
    end

    
  endrule : rl_LOOP_V1_INIT_FP_ADD

  // changed this loop
  rule rl_LOOP_V1_DONE_FP_ADD(currState == LOOP_V1_DONE_FP_ADD);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    let v1_result = fpAddResult1;

    // Write to external vCurrReg
    // VRegAddr addr = truncate(stateIndex - 1);
    // writeReqFIFO_VCurr.enq(MemWriteReq{addr: addr, data: v1_result});
    let stateIndex_1 = stateIndex - 1;
    BackTraceAddr addr = baseAddrVCurr + zeroExtend(stateIndex_1);
    // BackTraceAddr addr = calcVCurrAddr(maxInputSeqLength, stateIndex_1);
    writeReqFIFO_BTB.enq(MemWriteReq{addr: addr, data: v1_result});
    
    $display("[DUT] Time=%0t: Writing V1[%d] = %h to vCurr[%d]", $time, stateIndex, v1_result, addr);
    currState <= LOOP_V1_NEXT_STATE;
  endrule : rl_LOOP_V1_DONE_FP_ADD

  rule rl_LOOP_V1_NEXT_STATE(currState == LOOP_V1_NEXT_STATE);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    // Check if any more states to process
    if (stateIndex == stateCount) begin
      $display("[DUT] Time=%0t: Completed V1 computation for all %d states", $time, stateCount);
      currState <= V1_CALC_END;
    end else begin
      stateIndex <= stateIndex + 1;
      $display("[DUT] Time=%0t: Moving to next state %d", $time, stateIndex + 1);
      currState <= LOOP_V1_INIT_GET_AB; // Loop back
    end
  endrule : rl_LOOP_V1_NEXT_STATE

  rule rl_V1_CALC_END(currState == V1_CALC_END);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    $display("[DUT] Time=%0t: V1 calculation complete : Swapping vCurr to vPrev", $time);

    // Start the swap process
    prevStateIndex <= 0;  // counter
    inputIndex <= inputIndex + 1;
    timeStep <= 1;
    currState <= SWAP_INIT;

  endrule : rl_V1_CALC_END

  // Swap states
  rule rl_SWAP_INIT(currState == SWAP_INIT);
    $display("[DUT] Time=%0t: SWAP_INIT", $time);
    prevStateIndex <= 0;
    // Validate inputSequenceLength
    let validInputSeqLength = validateSeqLength(timeStep);
    if (!validInputSeqLength) begin
      $display("[DUT][ERROR] Time=%0t: Received illegal Input Sequence Length", $time);
      currState <= INPUT_ERROR;
    end else begin
     currState <= SWAP_READ_VCURR;
    end
    // currState <= SWAP_READ_VCURR;
  endrule

  rule rl_SWAP_READ_VCURR(currState == SWAP_READ_VCURR);
    $display("[DUT] Time=%0t: SWAP_READ_VCURR index=%d", $time, prevStateIndex);
    
    if (prevStateIndex < truncate(nValue)) begin
      BackTraceAddr addr = baseAddrVCurr + zeroExtend(prevStateIndex);
      // BackTraceAddr addr = calcVCurrAddr(maxInputSeqLength, prevStateIndex);
      // VRegAddr addr = truncate(prevStateIndex);
      readReqFIFO_BTB1.enq(MemReq{addr: addr});
      currState <= SWAP_WRITE_VPREV;
    end else begin
      $display("[DUT] Time=%0t: Swap complete", $time);
      currState <= VT_CALC_START;
    end
  endrule

  rule rl_SWAP_WRITE_VPREV(currState == SWAP_WRITE_VPREV);
    $display("[DUT] Time=%0t: SWAP_WRITE_VPREV", $time);
    
    // let resp = readRespFIFO_VCurr.first;
    // readRespFIFO_VCurr.deq;
    let resp = readRespFIFO_BTB1.first;
    readRespFIFO_BTB1.deq;
    
    // VRegAddr addr = truncate(prevStateIndex);
    // writeReqFIFO_VPrev.enq(MemWriteReq{addr: addr, data: resp.data});
    BackTraceAddr addr = baseAddrVPrev + zeroExtend(prevStateIndex);
    // BackTraceAddr addr = calcVPrevAddr(maxInputSeqLength, prevStateIndex, nValue);
    writeReqFIFO_BTB.enq(MemWriteReq{addr: addr, data: resp.data});
    
    prevStateIndex <= prevStateIndex + 1;
    currState <= SWAP_READ_VCURR;
  endrule


  // Vt Calculation: Recursive till end.
  rule rl_VT_CALC_START(currState == VT_CALC_START);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    $display("[DUT] Time=%0t: Starting Vt calculation for t=%d", $time, timeStep);
    readReqFIFO_Input1.enq(MemReq{addr:inputIndex});
    $display("[DUT] Time=%0t: Requesting observation at index %d", $time, inputIndex);
    currState <= VT_GET_INPUT;
  endrule : rl_VT_CALC_START

  rule rl_VT_GET_INPUT(currState == VT_GET_INPUT);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    let respInput = readRespFIFO_Input1.first;
    readRespFIFO_Input1.deq;
    $display("[DUT] Time=%0t: Received Input = %h", $time, respInput.data);

    // Validate input
    // Check for seqEndPrecursorFF
    if (respInput.data == 32'hFFFFFFFF) begin
      $display("[DUT] Time=%0t: End marker detected at t=%d", $time, timeStep);
      $display("[DUT] Time=%0t: Sequence length = %d observations", $time, timeStep );
      currState <= TRACEBACK_CALC_START;
    end else begin
      let isValidInputVt = validateVtInput(respInput.data, mValue); 
      if (!isValidInputVt) begin
        $display("[DUT][ERROR] Time=%0t: Invalid observation %d (max possible = %d)", $time, respInput.data, mValue);
        currState <= INPUT_ERROR;
        rg_input_err <= True;
      end else begin
        inputValue <= respInput.data;
        $display("[DUT] Time=%0t: Received observation o_%d = %d", $time, timeStep, respInput.data);
        currState <= VT_INIT_J_LOOP;
      end
    end
  endrule : rl_VT_GET_INPUT

  rule rl_VT_INIT_J_LOOP(currState == VT_INIT_J_LOOP);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    $display("[DUT] Time=%0t: j-loop : Starting Vt computation for t=%d, N=%d states", $time, timeStep, nValue);
    // for j = 1
    stateIndex <= 1;
    currState <= VT_INIT_I_LOOP;
  endrule : rl_VT_INIT_J_LOOP

  rule rl_VT_INIT_I_LOOP(currState == VT_INIT_I_LOOP);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    $display("[DUT] Time=%0t: i-loop: Computing max path metric to state j=%d", $time, stateIndex);
    // for i = 1
    prevStateIndex <= 1;

    // Initialize maximum probability and best previous states
    maxProb <= 32'hFFFFFFFF;
    // !!!! maxProb <= 32'h00000000;
    bestPrevState <= 0;
    
    $display("[DUT] Time=%0t: i-loop: Checking prevStates i=1 to %d", $time, nValue);
    currState <= VT_GET_PREV_PROB;
  endrule : rl_VT_INIT_I_LOOP

  rule rl_VT_GET_PREV_PROB(currState == VT_GET_PREV_PROB);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    // Read from external vPrevReg
    // VRegAddr addr = truncate(prevStateIndex - 1);
    // readReqFIFO_VPrev.enq(MemReq{addr: addr});
    let prevStateIndex_1 = prevStateIndex - 1;
    BackTraceAddr addr = baseAddrVPrev + zeroExtend(prevStateIndex_1);
    // BackTraceAddr addr = calcVPrevAddr(maxInputSeqLength, prevStateIndex_1, nValue);
    readReqFIFO_BTB1.enq(MemReq{addr: addr});
    
    $display("[DUT] Time=%0t: i-loop: Requesting V_{t-1}[i=%d]", $time, prevStateIndex);
    currState <= VT_READ_VPREV_WAIT;
  endrule : rl_VT_GET_PREV_PROB
  
  rule rl_VT_READ_VPREV_WAIT(currState == VT_READ_VPREV_WAIT);
    $display("[DUT] Time=%0t: VT_READ_VPREV_WAIT", $time);
    
    // let resp = readRespFIFO_VPrev.first;
    // readRespFIFO_VPrev.deq;
    let resp = readRespFIFO_BTB1.first;
    readRespFIFO_BTB1.deq;
    prevProb <= resp.data;
    
    $display("[DUT] Time=%0t: i-loop: Received V_{t-1}[i=%d] = %h", $time, prevStateIndex, resp.data);
    currState <= VT_INIT_GET_AB;
  endrule : rl_VT_READ_VPREV_WAIT

  // Opt for b_single :: b is now added only to final prob
  rule rl_VT_INIT_GET_AB(currState == VT_INIT_GET_AB);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    
    // Calculate addresses for accessing A and B matrices
    AMatrixAddr prevStateIndex_ext = zeroExtend(pack(prevStateIndex));
    AMatrixAddr stateIndex_A_ext = zeroExtend(pack(stateIndex));
    AMatrixAddr nValue_ext = truncate(pack(nValue));

    // Opt for b_single :: removed b-Fetch
    // Opt for b_single :: BMatrixAddr stateIndex_B_ext = zeroExtend(pack(stateIndex));
    // Opt for b_single :: BMatrixAddr inputValue_ext = truncate(pack(inputValue));
    // Opt for b_single :: BMatrixAddr mValue_ext = truncate(pack(mValue));

    // Fetch A[i*N][j-1]
    AMatrixAddr aIndex = (prevStateIndex_ext * nValue_ext + (stateIndex_A_ext - 1));
    readReqFIFO_A1.enq(MemReq{addr: aIndex});

    // Opt for b_single :: Fetch B[(j-1)*M][input-1]
    // Opt for b_single :: BMatrixAddr bIndex = (stateIndex_B_ext - 1) * mValue_ext + (inputValue_ext - 1);
    // Opt for b_single :: readReqFIFO_B1.enq(MemReq{addr: bIndex});

    // Opt for b_single ::$display("[DUT] Time=%0t: i-loop: Requesting A[%d][%d] @ address %d, B[%d][%d] @ address %d", $time, prevStateIndex, stateIndex, aIndex, stateIndex, inputValue, bIndex);
    $display("[DUT] Time=%0t: i-loop: Requesting A[%d][%d] @ address %d", $time, prevStateIndex, stateIndex, aIndex);
    currState <= VT_DONE_GET_AB;
  endrule : rl_VT_INIT_GET_AB

  rule rl_VT_DONE_GET_AB(currState == VT_DONE_GET_AB);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    
    // Receive A
    let respA = readRespFIFO_A1.first;
    readRespFIFO_A1.deq;
    aValue <= respA.data;
    $display("[DUT] Time=%0t: i-loop: Received A[%d][%d] = %h (log prob)", $time, prevStateIndex, stateIndex, respA.data);

    // Opt for b_single :: // Receive B
    // Opt for b_single :: let respB = readRespFIFO_B1.first;
    // Opt for b_single :: readRespFIFO_B1.deq;
    // Opt for b_single :: bValue <= respB.data;
    // Opt for b_single :: $display("[DUT] Time=%0t: Received B[%d][%d] = %h (log prob)", $time, stateIndex, inputValue, respB.data);

    // Validate A and B probabilities
    // If positive, move to input error
    // Using msb function that BSV provides
    // Optimised :: if (msb(respA.data) == 1'b0 || msb(respB.data) == 1'b0) begin
    if (msb(respA.data) == 1'b0) begin
      $display("[DUT][ERROR] Time=%0t: Invalid probability", $time);
      currState <= INPUT_ERROR;
      rg_input_err <= True;
    end else begin
      currState <= VT_INIT_FP_ADD;
    end
  endrule : rl_VT_DONE_GET_AB

  rule rl_VT_INIT_FP_ADD(currState == VT_INIT_FP_ADD);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));

    // V_{t-1} + A[i][j]
    // Added fpError :: let sum1 <- fpAdder1.add(prevProb, aValue);
    // Added fpError :: fpAddResult1 <= sum1;
    let addResult <- fpAdder1.add(prevProb, aValue);
    match {.sum1, .error} = addResult;
    fpAddResult1 <= sum1;
    if (error == 1'b1) begin
        $display("[DUT][ERROR] Time=%0t: FP Error from FP Adder for sum1 = %h", $time, sum1);
        rg_fp_err <= True;
        currState <= FP_ERROR;
    end
    else begin
        currState <= VT_DONE_FP_ADD;
    end
    
    // currState <= VT_PROC_FP_ADD;
  endrule : rl_VT_INIT_FP_ADD

  // Opt for b_single :: rule rl_VT_PROC_FP_ADD(currState == VT_PROC_FP_ADD);
  // Opt for b_single ::   $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
  // Opt for b_single ::   let tempVar = fpAddResult1;

  // Opt for b_single ::   // tempVar + B[j][input]
  // Opt for b_single ::   let sum2 <- fpAdder1.add(tempVar, bValue);
  // Opt for b_single ::   fpAddResult1 <= sum2;
  // Opt for b_single ::   currState <= VT_DONE_FP_ADD;

  // Opt for b_single :: endrule : rl_VT_PROC_FP_ADD

  rule rl_VT_DONE_FP_ADD(currState == VT_DONE_FP_ADD);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    let currProb = fpAddResult1;
    $display("[DUT] Time=%0t: i-loop: Current path probability via prevState %d = %h", $time, prevStateIndex, currProb);

    // Update maxProb
    // $display("DEBUG : currProb = %h || maxProb = %h", currProb, maxProb);
    // Comparison is sequential, using < would ensure equal prob would get value from
    // lower state
    // < because negative probabilities - init to FF
    if (currProb < maxProb) begin
    // !!! if (currProb > maxProb) begin
      // $display("DEBUG : In loop");
      maxProb <= currProb;
      bestPrevState <= truncate(prevStateIndex);
    end
    currState <= VT_LOOP_I_LOOP;
  endrule : rl_VT_DONE_FP_ADD

  rule rl_VT_LOOP_I_LOOP(currState == VT_LOOP_I_LOOP);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    // Check if all prevStates are covered
    if (prevStateIndex == truncate(nValue)) begin
      // currState <= VT_CALC_MAX_PROB;
      currState <= VT_SAVE_STATE;
    end else begin
      prevStateIndex <= prevStateIndex + 1;
      currState <= VT_GET_PREV_PROB;
    end
  endrule : rl_VT_LOOP_I_LOOP

  // Fetch B matrix once per j-state (after finding max)
  rule rl_VT_SAVE_STATE(currState == VT_SAVE_STATE);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    $display("[DUT] Time=%0t: j-loop: Max path to state %d found (bestPrevState=%d), now fetching B", $time, stateIndex, bestPrevState);

    BMatrixAddr stateIndex_B_ext = zeroExtend(pack(stateIndex));
    BMatrixAddr inputValue_ext = truncate(pack(inputValue));
    BMatrixAddr mValue_ext = truncate(pack(mValue));
    BMatrixAddr bIndex = (stateIndex_B_ext - 1) * mValue_ext + (inputValue_ext - 1);
    
    readReqFIFO_B1.enq(MemReq{addr: bIndex});
    $display("[DUT] Time=%0t: Requesting B[%d][%d] @ address %d", $time, stateIndex, inputValue, bIndex);
    
    currState <= VT_GET_B_AND_ADD;
  endrule : rl_VT_SAVE_STATE


  // Receive B matrix response
  rule rl_VT_GET_B_AND_ADD(currState == VT_GET_B_AND_ADD);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    
    let respB = readRespFIFO_B1.first;
    readRespFIFO_B1.deq;
    bValue <= respB.data;
    $display("[DUT] Time=%0t: Received B[%d][%d] = %h (log prob)", $time, stateIndex, inputValue, respB.data);
    
    if (msb(respB.data) == 1'b0) begin
      $display("[DUT][ERROR] Time=%0t: Invalid probability", $time);
      currState <= INPUT_ERROR;
      rg_input_err <= True;
    end else begin
      currState <= VT_ADD_B_TO_MAX;
    end
  endrule : rl_VT_GET_B_AND_ADD


  // Add B to the maximum probability
  rule rl_VT_ADD_B_TO_MAX(currState == VT_ADD_B_TO_MAX);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    
    // maxProb + B
    // Added fpError :: let finalProb <- fpAdder1.add(maxProb, bValue);
    // Added fpError :: fpAddResult1 <= finalProb;
    let addResult <- fpAdder1.add(maxProb, bValue);
    match {.finalProb, .error} = addResult;
    fpAddResult1 <= finalProb;
    if (error == 1'b1) begin
        $display("[DUT][ERROR] Time=%0t: FP Error from FP Adder for finalProb = %h", $time, finalProb);
        rg_fp_err <= True;
        currState <= FP_ERROR;
    end
    else begin
        $display("[DUT] Time=%0t: Computing final probability: max + B", $time);
    
        currState <= VT_STORE_RESULT;
    end
  endrule : rl_VT_ADD_B_TO_MAX


  // Store the final result
  rule rl_VT_STORE_RESULT(currState == VT_STORE_RESULT);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    
    let finalProb = fpAddResult1;
    
    // Write to external vCurrReg
    // VRegAddr vAddr = truncate(stateIndex - 1);
    // writeReqFIFO_VCurr.enq(MemWriteReq{addr: vAddr, data: finalProb});
    let stateIndex_1 = stateIndex - 1;
    BackTraceAddr vAddr = baseAddrVCurr + zeroExtend(stateIndex_1);
    // BackTraceAddr vAddr = calcVCurrAddr(maxInputSeqLength, stateIndex_1);
    writeReqFIFO_BTB.enq(MemWriteReq{addr: vAddr, data: finalProb});
    $display("[DUT] Time=%0t: j-loop: Storing V_t[%d] = %h to vCurr[%d]", 
            $time, stateIndex, finalProb, vAddr);
    
    currState <= VT_STORE_BTB;
  endrule : rl_VT_STORE_RESULT

  rule rl_VT_STORE_BTB(currState == VT_STORE_BTB);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    BackTraceAddr btAddr = getBackTraceAddr(timeStep, stateIndex, nValue);
    let bestPrevState_ZE = zeroExtend(bestPrevState);
    writeReqFIFO_BTB.enq(MemWriteReq{addr: btAddr,
                                        data: bestPrevState_ZE});
    
    $display("[DUT] Time=%0t: j-loop: Storing backtrace[%d][%d] = %d @ btAddr %d", 
            $time, timeStep, stateIndex, bestPrevState, btAddr);
    currState <= VT_LOOP_J_LOOP;

  endrule : rl_VT_STORE_BTB

  // After VT_LOOP_J_LOOP, when all states computed
  rule rl_VT_LOOP_J_LOOP (currState == VT_LOOP_J_LOOP);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    
    if (stateIndex == truncate(nValue)) begin
      // All Vt values computed, start sequential min-finding
      currState <= VT_MIN_INIT;
      $display("[DUT] Time=%0t: Starting sequential min-reduction", $time);
    end else begin
      stateIndex <= stateIndex + 1;
      currState <= VT_INIT_I_LOOP;
    end
  endrule : rl_VT_LOOP_J_LOOP


  // Initialize sequential min-finding
  rule rl_VT_MIN_INIT (currState == VT_MIN_INIT);
    $display("[DUT] Time=%0t: VT_MIN_INIT", $time);
    minIdx <= 0;
    bestMin <= 32'hFFFFFFFF;  // Worst possible (max negative log prob)
    bestMinIdx <= 0;
    currState <= VT_MIN_READ;
  endrule : rl_VT_MIN_INIT


  // Read vCurr value sequentially
  rule rl_VT_MIN_READ (currState == VT_MIN_READ);
    $display("[DUT] Time=%0t: VT_MIN_READ index=%d", $time, minIdx);
    // let compareValue = (maxInputSeqLength + truncate(nValue));
    
    if (minIdx < truncate(nValue)) begin
      // VRegAddr addr = truncate(minIdx);
      // readReqFIFO_VCurr.enq(MemReq{addr: addr});
      BackTraceAddr addr = baseAddrVCurr + zeroExtend(minIdx);
      // BackTraceAddr addr = calcVCurrAddr(maxInputSeqLength, minIdx);
      readReqFIFO_BTB1.enq(MemReq{addr: addr});
      currState <= VT_MIN_WAIT;
    end else begin
      // Done with all values 
      finalMaxProb <= bestMin;
      bestFinalState <= bestMinIdx + 1;
      currState <= VT_MIN_DONE;
      $display("[DUT] Time=%0t: Min-reduction complete: state=%d, prob=%h", 
              $time, bestMinIdx + 1, bestMin);
    end
  endrule : rl_VT_MIN_READ


  // Compare read value with current minimum
  rule rl_VT_MIN_WAIT (currState == VT_MIN_WAIT);
    $display("[DUT] Time=%0t: VT_MIN_WAIT", $time);
    
    // let resp = readRespFIFO_VCurr.first;
    // readRespFIFO_VCurr.deq;
    let resp = readRespFIFO_BTB1.first;
    readRespFIFO_BTB1.deq;
    
    Word currVal = resp.data;
    $display("[DUT] Time=%0t: Read vCurr[%d] = %h", $time, minIdx, currVal);
    
    // Area optimisation : single 32-bit comparison
    if (currVal < bestMin) begin
      bestMin <= currVal;
      bestMinIdx <= minIdx;
      $display("[DUT] Time=%0t: New minimum found: index=%d, value=%h", 
              $time, minIdx, currVal);
    end
    
    minIdx <= minIdx + 1;
    currState <= VT_MIN_READ;
  endrule : rl_VT_MIN_WAIT


  // Transition to next iteration
  rule rl_VT_MIN_DONE (currState == VT_MIN_DONE);
    $display("[DUT] Time=%0t: VT_MIN_DONE", $time);
    
    inputIndex <= inputIndex + 1;
    timeStep <= timeStep + 1;
    currState <= SWAP_INIT;
  endrule : rl_VT_MIN_DONE


  // TraceBack Calculation Start
  rule rl_TRACEBACK_CALC_START(currState == TRACEBACK_CALC_START);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    $display("[DUT] Time=%0t: Traceback: Total timeSteps: %d", $time, timeStep);

    traceBackTime <= timeStep - 1;
    currTraceState <= bestFinalState;

    currState <= TRACEBACK_LOOP_START;
  endrule : rl_TRACEBACK_CALC_START



  rule rl_TRACEBACK_LOOP_START(currState == TRACEBACK_LOOP_START);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));

    // Write current state to output [traceBackTime - 1]
    OutputMatrixAddr outAddr = zeroExtend(traceBackTime ) + outputOffset;
    writeReqFIFO_Output.enq(MemWriteReq{addr: outAddr,
                                        data: zeroExtend(currTraceState)});
    $display("DEBUG : [DUT] Time=%0t: Write state %d (timestep %d) to output[%0d]", 
           $time, currTraceState, traceBackTime, outAddr);          

    // Finished writing other timesteps BackTo1
    if (traceBackTime == 0) begin
      currState <= TRACEBACK_WRITE_FINAL_PROB;
    end else begin
      BackTraceAddr bTAddr = getBackTraceAddr(traceBackTime, currTraceState, nValue);
      // backTraceBuffer moved outside :: Bit#(5) bTState = backTraceBuffer.sub(bTAddr);
      readReqFIFO_BTB1.enq(MemReq{addr:bTAddr});
      
      // $display("DEBUG : [DUT] Time=%0t: backtrace[%d][%d] = %d", $time, traceBackTime, currTraceState, bTState);
      // currTraceState <= bTState;
      // traceBackTime <= traceBackTime - 1;
      currState <= TRACEBACK_LOOP_EXEC;
    end
  endrule : rl_TRACEBACK_LOOP_START

  rule rl_TRACEBACK_LOOP_EXEC(currState == TRACEBACK_LOOP_EXEC);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    let respBTB = readRespFIFO_BTB1.first;
    readRespFIFO_BTB1.deq;
    $display("DEBUG : [DUT] Time=%0t: backtrace[%d][%d] = %d", $time, traceBackTime, currTraceState, respBTB.data);
    currTraceState <= truncate(respBTB.data);
    traceBackTime <= traceBackTime - 1;
    currState <= TRACEBACK_LOOP_START;
  endrule : rl_TRACEBACK_LOOP_EXEC

  rule rl_TRACEBACK_WRITE_FINAL_PROB(currState == TRACEBACK_WRITE_FINAL_PROB);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));

    OutputMatrixAddr lastAddr = zeroExtend(timeStep ) + outputOffset;
    writeReqFIFO_Output.enq(MemWriteReq{addr: lastAddr,
                                     data: finalMaxProb});
    $display("[DUT] Time=%0t: Write final prob %h to output[%0d]", $time, finalMaxProb, lastAddr);

    // Go back to V1 calc for next sequence (if any) 
    inputIndex <= inputIndex + 1;
    // Clear all registers used for computation for new sequence
    outputOffset <= lastAddr + 1;
    currState <= WRITE_FF_MARKER;


  endrule : rl_TRACEBACK_WRITE_FINAL_PROB

  rule rl_WRITE_FF_MARKER(currState == WRITE_FF_MARKER);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    // Write FFFF to mark end of current sequence 
    writeReqFIFO_Output.enq(MemWriteReq{addr: outputOffset,
                                        data: 32'hFFFFFFFF});

    outputOffset <= outputOffset + 1;
    currState <= V1_CALC_START;
  endrule : rl_WRITE_FF_MARKER


  // Input Error
  rule rl_INPUT_ERROR(currState == INPUT_ERROR);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    rg_input_err <= False; // Resetting to make it single-cycle pulse
    currState <= DONE;
  endrule : rl_INPUT_ERROR

  rule rl_FP_ERROR(currState == FP_ERROR);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    rg_fp_err <= False;  // Reset to make it single-cycle pulse
    currState <= DONE;
  endrule : rl_FP_ERROR


  // NOTE: Consider adding an rl_COMPLETE stage if done should be 0 in IDLE state
  rule rl_DONE(currState == DONE && rg_start && !rg_done);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    currState <= IDLE;
    // Write EOF 0
    writeReqFIFO_Output.enq(MemWriteReq{addr: outputOffset,
                                     data: 32'h00000000});
    rg_done <= True;
    rg_start <= False;
  endrule : rl_DONE



  
  //=========================
  // Method Implementations
  //-------------------------
  // Control
  method Action start() if (!rg_start);
    rg_start <= True;
    // $display("[DUT] Time=%0t: Viterbi decoder started", $time);
  endmethod
  
  method Bool done();
    return rg_done;
  endmethod

  // Error
  method Bool inputError();
    return rg_input_err;
  endmethod
  
  method Bool fpError();
    return rg_fp_err;
  endmethod

  // Memory Interface
  // Req  : Send out first req from FIFO
  // Resp : Enq response to FIFO
  method ActionValue#(MemReq#(NMAddr)) readReq_NM1();
    let req = readReqFIFO_NM1.first;
    readReqFIFO_NM1.deq();
    return req;
  endmethod

  method Action readResp_NM1(MemResp resp);
    readRespFIFO_NM1.enq(resp);
  endmethod

  method ActionValue#(MemReq#(NMAddr)) readReq_NM2();
    let req = readReqFIFO_NM2.first;
    readReqFIFO_NM2.deq();
    return req;
  endmethod

  method Action readResp_NM2(MemResp resp);
    readRespFIFO_NM2.enq(resp);
  endmethod

  method ActionValue#(MemReq#(AMatrixAddr)) readReq_A1();
    let req = readReqFIFO_A1.first;
    readReqFIFO_A1.deq();
    return req;
  endmethod

  method Action readResp_A1(MemResp resp);
    readRespFIFO_A1.enq(resp);
  endmethod

  // Removing unused ports :: method ActionValue#(MemReq#(AMatrixAddr)) readReq_A2();
  // Removing unused ports ::   let req = readReqFIFO_A2.first;
  // Removing unused ports ::   readReqFIFO_A2.deq();
  // Removing unused ports ::   return req;
  // Removing unused ports :: endmethod

  // Removing unused ports :: method Action readResp_A2(MemResp resp);
  // Removing unused ports ::   readRespFIFO_A2.enq(resp);
  // Removing unused ports :: endmethod

  method ActionValue#(MemReq#(BMatrixAddr)) readReq_B1();
    let req = readReqFIFO_B1.first;
    readReqFIFO_B1.deq();
    return req;
  endmethod

  method Action readResp_B1(MemResp resp);
    readRespFIFO_B1.enq(resp);
  endmethod

  // Removing unused ports :: method ActionValue#(MemReq#(BMatrixAddr)) readReq_B2();
  // Removing unused ports ::   let req = readReqFIFO_B2.first;
  // Removing unused ports ::   readReqFIFO_B2.deq();
  // Removing unused ports ::   return req;
  // Removing unused ports :: endmethod

  // Removing unused ports :: method Action readResp_B2(MemResp resp);
  // Removing unused ports ::   readRespFIFO_B2.enq(resp);
  // Removing unused ports :: endmethod

  method ActionValue#(MemReq#(InputMatrixAddr)) readReq_Input1();
    let req = readReqFIFO_Input1.first;
    readReqFIFO_Input1.deq();
    return req;
  endmethod

  method Action readResp_Input1(MemResp resp);
    readRespFIFO_Input1.enq(resp);
  endmethod

  // Removing unused ports :: method ActionValue#(MemReq#(InputMatrixAddr)) readReq_Input2();
  // Removing unused ports ::   let req = readReqFIFO_Input2.first;
  // Removing unused ports ::   readReqFIFO_Input2.deq();
  // Removing unused ports ::   return req;
  // Removing unused ports :: endmethod

  // Removing unused ports :: method Action readResp_Input2(MemResp resp);
  // Removing unused ports ::   readRespFIFO_Input2.enq(resp);
  // Removing unused ports :: endmethod

  method ActionValue#(MemWriteReq#(OutputMatrixAddr)) writeReq_Output();
    let writeReq = writeReqFIFO_Output.first;
    writeReqFIFO_Output.deq();
    return writeReq;
  endmethod

  method ActionValue#(MemReq#(BackTraceAddr)) readReq_BTB1();
    let req = readReqFIFO_BTB1.first;
    readReqFIFO_BTB1.deq;
    return req;
  endmethod

  method Action readResp_BTB1(MemResp resp);
    readRespFIFO_BTB1.enq(resp);
  endmethod

  method ActionValue#(MemWriteReq#(BackTraceAddr)) writeReq_BTB();
    let writeReq = writeReqFIFO_BTB.first;
    writeReqFIFO_BTB.deq;
    return writeReq;
  endmethod

 // Removed :: // VCurr memory interface 
 // Removed ::  method ActionValue#(MemReq#(VRegAddr)) readReq_VCurr;
 // Removed ::    let req = readReqFIFO_VCurr.first;
 // Removed ::    readReqFIFO_VCurr.deq;
 // Removed ::    return req;
 // Removed ::  endmethod

 // Removed ::  method Action readResp_VCurr(MemResp resp);
 // Removed ::    readRespFIFO_VCurr.enq(resp);
 // Removed ::  endmethod

 // Removed ::  method ActionValue#(MemWriteReq#(VRegAddr)) writeReq_VCurr;
 // Removed ::    let req = writeReqFIFO_VCurr.first;
 // Removed ::    writeReqFIFO_VCurr.deq;
 // Removed ::    return req;
 // Removed ::  endmethod

 // Removed ::  // VPrev memory interface methods
 // Removed ::  method ActionValue#(MemReq#(VRegAddr)) readReq_VPrev;
 // Removed ::    let req = readReqFIFO_VPrev.first;
 // Removed ::    readReqFIFO_VPrev.deq;
 // Removed ::    return req;
 // Removed ::  endmethod

 // Removed ::  method Action readResp_VPrev(MemResp resp);
 // Removed ::    readRespFIFO_VPrev.enq(resp);
 // Removed ::  endmethod

 // Removed ::  method ActionValue#(MemWriteReq#(VRegAddr)) writeReq_VPrev;
 // Removed ::    let req = writeReqFIFO_VPrev.first;
 // Removed ::    writeReqFIFO_VPrev.deq;
 // Removed ::    return req;
 // Removed ::  endmethod

  //---------------------------------------------------
  endmodule : mkViterbiDecoder

endpackage : ViterbiDecoder
