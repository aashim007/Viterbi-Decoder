  rule rl_GET_INPUT_V1(currState == GET_INPUT_V1);
    $display("[DUT] Time=%0t: Current State = ", $time, fshow(currState));
    let respInput = readRespFIFO_Input1.first;
    readRespFIFO_Input1.deq;
    if (respInput.data == 32'h00000000) begin
      $display("DEBUG : [DUT] Time=%0t: EOF detected. Going to DONE State!", $time);
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
