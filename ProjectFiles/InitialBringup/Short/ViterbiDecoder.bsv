// RTL for Viterbi Decoder
package ViterbiDecoder;
  import ViterbiCommon::*;
  import RegFile::*;
  import FIFOF::*;
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
    method ActionValue#(MemReq#(AMatrixAddr)) readReq_A2();
    method Action readResp_A2(MemResp resp);

    method ActionValue#(MemReq#(BMatrixAddr)) readReq_B1();
    method Action readResp_B1(MemResp resp);
    method ActionValue#(MemReq#(BMatrixAddr)) readReq_B2();
    method Action readResp_B2(MemResp resp);

    method ActionValue#(MemReq#(InputMatrixAddr)) readReq_Input1();
    method Action readResp_Input1(MemResp resp);
    method ActionValue#(MemReq#(InputMatrixAddr)) readReq_Input2();
    method Action readResp_Input2(MemResp resp);

    method ActionValue#(MemWriteReq#(OutputMatrixAddr)) writeReq_Output();

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
    LOOP_V1_DONE_ADD,
    LOOP_V1_OUTPUT,
    LOOP_V1_NEXT,
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
    VT_PROC_FP_ADD, // fires intermediate + B
    VT_DONE_FP_ADD, // both sums done
    VT_LOOP_I_LOOP,
    VT_SAVE_STATE,
    VT_LOOP_J_LOOP,
    VT_UPDATE_VREG,
    
    // Traceback & Write output probable state
    TRACEBACK_CALC_START,
    TRACEBACK_LOOP,
    TRACEBACK_WRITE_FINAL_PROB,
    
    // Finish States
    WRITE_FF_MARKER,
    DONE,
    INPUT_ERROR,
    FP_ERROR

  } ViterbiState deriving (Bits, Eq, FShow);

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
  FIFOF#(MemReq#(NMAddr)) readReqFIFO_NM1   <- mkFIFOF;
  FIFOF#(MemResp)         readRespFIFO_NM1  <- mkFIFOF;
  FIFOF#(MemReq#(NMAddr)) readReqFIFO_NM2   <- mkFIFOF;
  FIFOF#(MemResp)         readRespFIFO_NM2  <- mkFIFOF;
  
  FIFOF#(MemReq#(AMatrixAddr))  readReqFIFO_A1   <- mkFIFOF;
  FIFOF#(MemResp)               readRespFIFO_A1  <- mkFIFOF;
  FIFOF#(MemReq#(AMatrixAddr))  readReqFIFO_A2   <- mkFIFOF;
  FIFOF#(MemResp)               readRespFIFO_A2  <- mkFIFOF;
  
  FIFOF#(MemReq#(BMatrixAddr))  readReqFIFO_B1   <- mkFIFOF;
  FIFOF#(MemResp)               readRespFIFO_B1  <- mkFIFOF;
  FIFOF#(MemReq#(BMatrixAddr))  readReqFIFO_B2   <- mkFIFOF;
  FIFOF#(MemResp)               readRespFIFO_B2  <- mkFIFOF;
  
  FIFOF#(MemReq#(InputMatrixAddr))  readReqFIFO_Input1   <- mkFIFOF;
  FIFOF#(MemResp)                   readRespFIFO_Input1  <- mkFIFOF;
  FIFOF#(MemReq#(InputMatrixAddr))  readReqFIFO_Input2   <- mkFIFOF;
  FIFOF#(MemResp)                   readRespFIFO_Input2  <- mkFIFOF;

  FIFOF#(MemWriteReq#(OutputMatrixAddr)) writeReqFIFO_Output <- mkFIFOF;

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

  Vector#(32, Reg#(Bit#(32))) vCurrReg <- replicateM(mkReg(0));
  Vector#(32, Reg#(Bit#(32))) vPrevReg <- replicateM(mkReg(0));

  Reg#(Bit#(5)) stateIndex <- mkReg(0);
  Reg#(Bit#(5)) stateCount <- mkReg(0);
  Reg#(Bit#(TimeBits)) timeStep <- mkReg(0);
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
  RegFile#(BackTraceAddr, Bit#(5)) backTraceBuffer <- mkRegFile(0,1023); // 33*31 = 1023
  // for 1024 :: RegFile#(BackTraceAddr, Bit#(5)) backTraceBuffer <- mkRegFile(0,31743); // 1024*31 = 31744
  Reg#(Bit#(TimeBits)) traceBackTime <- mkReg(0); // Very poetic variable.
  Reg#(Bit#(5)) currTraceState <- mkReg(0);



  // FP Adder
  Ifc_fp_adder fpAdder1 <- mkFpAdder;
  Ifc_fp_adder fpAdder2 <- mkFpAdder;

  Reg#(Word) fpAddResult1 <- mkReg(0);
  Reg#(Word) fpAddResult2 <- mkReg(0);

  // File Handling
  Reg#(Bool) seqEndPrecursorFF <- mkReg(False);
  Reg#(Bool) seqEndPrecursor00 <- mkReg(False);

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

  function Bit#(2) validateInput(Word inputWord, Word maxValue);
    // 00 - okay
    // 01 - received FF
    // 10 - received 00 (after FF)
    // 11 - illegal input
    if (inputWord == 32'hFFFFFFFF) begin
      return 2'b01;
    end 
    else if ((inputWord == 32'h00000000) && (seqEndPrecursorFF)) begin
      return 2'b10;
    end
    else if ((inputWord == 32'h00000000) || (inputWord > maxValue)) begin // illegal
      return 2'b11;
    end 
    else begin
      return 2'b00;
    end
  endfunction : validateInput

  function BackTraceAddr getBackTraceAddr(Bit#(TimeBits) time_step, Bit#(5) curr_state, Word max_state); 
    // Backtrace 2-D array BTB[time][state], indexing into row-major
    BackTraceAddr time_step_ext  = zeroExtend(time_step);
    BackTraceAddr curr_state_ext = zeroExtend(curr_state);
    BackTraceAddr max_state_ext = truncate(max_state);
    return ((time_step_ext * max_state_ext) + (curr_state_ext - 1));
  endfunction : getBackTraceAddr



  //==========================
  // New Rules
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
    currState <= V1_CALC_START;
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
    timeStep <= 1;
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
    let sum <- fpAdder1.add(aValue, bValue);
    fpAddResult1 <= sum;
    $display("[DUT] Time=%0t: Computing V1[%d] = A + B", $time, stateIndex);
    currState <= LOOP_V1_DONE_FP_ADD;
  endrule : rl_LOOP_V1_INIT_FP_ADD

  rule rl_LOOP_V1_DONE_FP_ADD(currState == LOOP_V1_DONE_FP_ADD);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    let v1_result = fpAddResult1;
    vCurrReg[stateIndex - 1] <= v1_result;
    $display("[DUT] Time=%0t: V1[%d] = %h", $time, stateIndex, v1_result);
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
    $display("[DUT] Time=%0t: V1 calculation complete", $time);
    // Copying vCurrReg to vPrevReg for next time step
    for (Integer i = 0; i < 32; i = i + 1) begin
      vPrevReg[i] <= vCurrReg[i];
    end

    // Next input
    inputIndex <= inputIndex + 1;
    timeStep <= 2;

    currState <= VT_CALC_START;
  endrule : rl_V1_CALC_END

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
      $display("[DUT] Time=%0t: Sequence length = %d observations", $time, timeStep - 1);
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

    // Get V(t-1)(i) from vPrevReg[i-1]
    Word prevValue = vPrevReg[prevStateIndex-1];
    prevProb <= prevValue; // storing to reg 
    $display("[DUT] Time=%0t: i-loop: V_{t-1}[i=%d] = %h", $time, prevStateIndex, prevValue);
    currState <= VT_INIT_GET_AB;
  endrule : rl_VT_GET_PREV_PROB

  rule rl_VT_INIT_GET_AB(currState == VT_INIT_GET_AB);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    
    // Calculate addresses for accessing A and B matrices
    AMatrixAddr prevStateIndex_ext = zeroExtend(pack(prevStateIndex));
    AMatrixAddr stateIndex_A_ext = zeroExtend(pack(stateIndex));
    AMatrixAddr nValue_ext = truncate(pack(nValue));

    BMatrixAddr stateIndex_B_ext = zeroExtend(pack(stateIndex));
    BMatrixAddr inputValue_ext = truncate(pack(inputValue));
    BMatrixAddr mValue_ext = truncate(pack(mValue));

    // Fetch A[i*N][j-1]
    AMatrixAddr aIndex = (prevStateIndex_ext * nValue_ext + (stateIndex_A_ext - 1));
    readReqFIFO_A1.enq(MemReq{addr: aIndex});

    // Fetch B[(j-1)*M][input-1]
    BMatrixAddr bIndex = (stateIndex_B_ext - 1) * mValue_ext + (inputValue_ext - 1);
    readReqFIFO_B1.enq(MemReq{addr: bIndex});

    $display("[DUT] Time=%0t: i-loop: Requesting A[%d][%d] @ address %d, B[%d][%d] @ address %d", $time, prevStateIndex, stateIndex, aIndex, stateIndex, inputValue, bIndex);
    currState <= VT_DONE_GET_AB;
  endrule : rl_VT_INIT_GET_AB

  rule rl_VT_DONE_GET_AB(currState == VT_DONE_GET_AB);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    
    // Receive A
    let respA = readRespFIFO_A1.first;
    readRespFIFO_A1.deq;
    aValue <= respA.data;
    $display("[DUT] Time=%0t: i-loop: Received A[%d][%d] = %h (log prob)", $time, prevStateIndex, stateIndex, respA.data);

    // Receive B
    let respB = readRespFIFO_B1.first;
    readRespFIFO_B1.deq;
    bValue <= respB.data;
    $display("[DUT] Time=%0t: Received B[%d][%d] = %h (log prob)", $time, stateIndex, inputValue, respB.data);

    // Validate A and B probabilities
    // If positive, move to input error
    // Using msb function that BSV provides
    if (msb(respA.data) == 1'b0 || msb(respB.data) == 1'b0) begin
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
    let sum1 <- fpAdder1.add(prevProb, aValue);
    fpAddResult1 <= sum1;
    currState <= VT_PROC_FP_ADD;
  endrule : rl_VT_INIT_FP_ADD

  rule rl_VT_PROC_FP_ADD(currState == VT_PROC_FP_ADD);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    let tempVar = fpAddResult1;

    // tempVar + B[j][input]
    let sum2 <- fpAdder1.add(tempVar, bValue);
    fpAddResult1 <= sum2;
    currState <= VT_DONE_FP_ADD;

  endrule : rl_VT_PROC_FP_ADD

  rule rl_VT_DONE_FP_ADD(currState == VT_DONE_FP_ADD);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    let currProb = fpAddResult1;
    $display("[DUT] Time=%0t: i-loop: Current path probability via prevState %d = %h", $time, prevStateIndex, currProb);

    // Update maxProb
    // $display("DEBUG : currProb = %h || maxProb = %h", currProb, maxProb);
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
      currState <= VT_SAVE_STATE;
    end else begin
      prevStateIndex <= prevStateIndex + 1;
      currState <= VT_GET_PREV_PROB;
    end
  endrule : rl_VT_LOOP_I_LOOP

  rule rl_VT_SAVE_STATE(currState == VT_SAVE_STATE);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));

    // Store maxProb and backTrace info
    vCurrReg[stateIndex - 1] <= maxProb;
    BackTraceAddr btAddr = getBackTraceAddr(timeStep, stateIndex, nValue);
    backTraceBuffer.upd(btAddr, bestPrevState);

    $display("[DUT] Time=%0t: j-loop: Storing V_t[%d] = %h, backtrace[%d][%d] = %d @ btAddr %d", $time, stateIndex, maxProb, timeStep, stateIndex, bestPrevState, btAddr);

    currState <= VT_LOOP_J_LOOP;
  endrule : rl_VT_SAVE_STATE

  rule rl_VT_LOOP_J_LOOP(currState == VT_LOOP_J_LOOP);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    
    // Check all states covered
    if (stateIndex == truncate(nValue)) begin
      currState <= VT_UPDATE_VREG;
    end else begin
      stateIndex <= stateIndex + 1;
      currState <= VT_INIT_I_LOOP; // this is the next state after VT_INIT_J_LOOP, that's why I_LOOP
    end
  endrule : rl_VT_LOOP_J_LOOP

  // !!!! NEXT: change VT_UPDATE_VREG to calculate max prob and best final state
  rule rl_VT_UPDATE_VREG(currState == VT_UPDATE_VREG);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    $display("[DUT] Time=%0t: j-loop completed: all %d states computed for t=%d", $time, nValue, timeStep);

    // Final max probability and state - init
    Word finalMaxProb_tmp = vCurrReg[0];
    Bit#(5) bestFinalState_tmp = 1;

    // Rewriting with correct bounds: for (Integer i = 0; i < 32; i = i + 1) begin
    // Rewriting with correct bounds:   // Getting best final prob and state
    // Rewriting with correct bounds:   if (vCurrReg[i] > finalMaxProb_tmp) begin
    // Rewriting with correct bounds:     finalMaxProb_tmp = vCurrReg[i];
    // Rewriting with correct bounds:     bestFinalState_tmp = fromInteger(i + 1);
    // Rewriting with correct bounds:   end
    // Rewriting with correct bounds:   // Saving back to vPrevReg
    // Rewriting with correct bounds:   vPrevReg[i] <= vCurrReg[i];
    // Rewriting with correct bounds: end


    for (Integer i = 0; i < valueOf(MaxNoOfStates); i = i + 1) begin
      // limit to current N
      Bit#(5) i5 = fromInteger(i);

      if (i5 < truncate(nValue)) begin
        let val = vCurrReg[i];
        if ((i != 0) && (val < finalMaxProb_tmp)) begin
        // if ((i != 0) && (val > finalMaxProb_tmp)) begin
          finalMaxProb_tmp = val;
          bestFinalState_tmp = fromInteger(i + 1);
        end
      end
      vPrevReg[i] <= vCurrReg[i];
    end

    // Store to reg
    finalMaxProb <= finalMaxProb_tmp;
    bestFinalState <= bestFinalState_tmp;

    inputIndex <= inputIndex + 1;
    timeStep <= timeStep + 1;

    // Onto next observation
    currState <= VT_CALC_START;
  endrule : rl_VT_UPDATE_VREG

  // TraceBack Calculation Start - the most critical portion!
  rule rl_TRACEBACK_CALC_START(currState == TRACEBACK_CALC_START);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    $display("[DUT] Time=%0t: Traceback: Total timeSteps: %d", $time, timeStep - 1);

    traceBackTime <= timeStep - 1;
    currTraceState <= bestFinalState;

    currState <= TRACEBACK_LOOP;
  endrule : rl_TRACEBACK_CALC_START

  rule rl_TRACEBACK_LOOP(currState == TRACEBACK_LOOP);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));

    // Write current state to output [traceBackTime - 1]
    OutputMatrixAddr outAddr = zeroExtend(traceBackTime - 1) + outputOffset;
    writeReqFIFO_Output.enq(MemWriteReq{addr: outAddr,
                                        data: zeroExtend(currTraceState)});
    $display("DEBUG : [DUT] Time=%0t: Write state %d (timestep %d) to output[%0d]", 
           $time, currTraceState, traceBackTime, outAddr);          

    // Finished writing other timesteps BackTo1
    if (traceBackTime == 1) begin
      currState <= TRACEBACK_WRITE_FINAL_PROB;
    end else begin
      BackTraceAddr bTAddr = getBackTraceAddr(traceBackTime, currTraceState, nValue);
      Bit#(5) bTState = backTraceBuffer.sub(bTAddr);
      $display("DEBUG : [DUT] Time=%0t: backtrace[%d][%d] = %d", 
             $time, traceBackTime, currTraceState, bTState);
      currTraceState <= bTState;
      traceBackTime <= traceBackTime - 1;
    end


    // Corrected :: if (traceBackTime == 1) begin
    // Corrected ::   $display("[DUT] Time=%0t: Write state %d t=1 at output[0]", $time, currTraceState);
    // Corrected ::   writeReqFIFO_Output.enq(MemWriteReq{addr: 0,
    // Corrected ::                                  data: zeroExtend(currTraceState)});
    // Corrected ::   currState <= TRACEBACK_WRITE_FINAL_PROB;
    // Corrected :: end else begin
    // Corrected ::   // Read from backTraceBuffer
    // Corrected ::   BackTraceAddr bTAddr = getBackTraceAddr(traceBackTime, currTraceState, nValue);
    // Corrected ::   Bit#(5) bTState = backTraceBuffer.sub(bTAddr);
    // Corrected ::   $display("DEBUG : [DUT] Time=%0t: bTAddr = %h bTState = %h", $time, bTAddr, bTState);

    // Corrected ::   // Write to output 
    // Corrected ::   OutputMatrixAddr outAddr = zeroExtend(traceBackTime - 1);
    // Corrected ::   writeReqFIFO_Output.enq(MemWriteReq{addr: outAddr,
    // Corrected ::                                  data: zeroExtend(bTState)});
    // Corrected ::   $display("[DUT] Time=%0t: Write state %d at time %d to output[%0d]", $time, bTState, traceBackTime - 1, outAddr);

    // Corrected ::   currTraceState <= bTState;
    // Corrected ::   traceBackTime <= traceBackTime - 1;      

    // Corrected :: end

  endrule : rl_TRACEBACK_LOOP

  rule rl_TRACEBACK_WRITE_FINAL_PROB(currState == TRACEBACK_WRITE_FINAL_PROB);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));

    OutputMatrixAddr lastAddr = zeroExtend(timeStep - 1) + outputOffset;
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
    $display("[DUT] Time=%0t: Viterbi decoder started", $time);
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

  method ActionValue#(MemReq#(AMatrixAddr)) readReq_A2();
    let req = readReqFIFO_A2.first;
    readReqFIFO_A2.deq();
    return req;
  endmethod

  method Action readResp_A2(MemResp resp);
    readRespFIFO_A2.enq(resp);
  endmethod

  method ActionValue#(MemReq#(BMatrixAddr)) readReq_B1();
    let req = readReqFIFO_B1.first;
    readReqFIFO_B1.deq();
    return req;
  endmethod

  method Action readResp_B1(MemResp resp);
    readRespFIFO_B1.enq(resp);
  endmethod

  method ActionValue#(MemReq#(BMatrixAddr)) readReq_B2();
    let req = readReqFIFO_B2.first;
    readReqFIFO_B2.deq();
    return req;
  endmethod

  method Action readResp_B2(MemResp resp);
    readRespFIFO_B2.enq(resp);
  endmethod

  method ActionValue#(MemReq#(InputMatrixAddr)) readReq_Input1();
    let req = readReqFIFO_Input1.first;
    readReqFIFO_Input1.deq();
    return req;
  endmethod

  method Action readResp_Input1(MemResp resp);
    readRespFIFO_Input1.enq(resp);
  endmethod

  method ActionValue#(MemReq#(InputMatrixAddr)) readReq_Input2();
    let req = readReqFIFO_Input2.first;
    readReqFIFO_Input2.deq();
    return req;
  endmethod

  method Action readResp_Input2(MemResp resp);
    readRespFIFO_Input2.enq(resp);
  endmethod

  method ActionValue#(MemWriteReq#(OutputMatrixAddr)) writeReq_Output();
    let writeReq = writeReqFIFO_Output.first;
    writeReqFIFO_Output.deq();
    return writeReq;
  endmethod

  //---------------------------------------------------
  endmodule : mkViterbiDecoder

endpackage : ViterbiDecoder
