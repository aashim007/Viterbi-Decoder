  rule rl_VALIDATE_INPUT_V1(currState == VALIDATE_INPUT_V1);
    let inputCheck = validateInput(inputValue, mValue);
    if (inputCheck == 2'b01) begin
      seqEndPrecursorFF <= True;
      currState <= INIT_COMPUTE_V1;
    end else if (inputCheck == 2'b10) begin
      seqEndPrecursor00 <= True;
      currState <= INIT_COMPUTE_V1;
    end else if (inputCheck == 2'b00) begin
      currState <= INIT_COMPUTE_V1;
    end else begin // illegal input
      rg_input_err <= True;
      currState <= INPUT_ERROR;
    end
  endrule : rl_VALIDATE_INPUT_V1

