//========================================
// README.md for Viterbi Decoder Project
//----------------------------------------

Overview of the Design
----------------------

    - Viterbi Decoder analyses a sequence of observations to predict the best possible sequence of hidden states that caused it. 
    - Our design - Implementation using Memory Interface & FSM (Init --> V1 Calc --> VT Calc (Recursive) --> Traceback --> OutputWrite)
    -   Optimisations carried out to improve PPA
    -   Final Results
        - Clock Period : 3.96 ns
        - Power : 548.352 uW 
        - Area : 17,158 um2


Individual Contributions
------------------------

Aashim Sikka (EE25M092)
    - RTL design of FP Adder and iterations with different adder types to optimise for Area
    - Synthesis iterations for obtaining best possible PPA Metrics

Rahul Anilkumar (CS25D007)
    - RTL design for Baseline Viterbi Decoder with interfaces and Finite State Machine with functional correctness
    - Automation of testbench framework and constrained random testcase generation

Combined Effort
    - Pseudo-code development for Viterbi Decoder functionality
    - Analysis of Baseline code to identify bottlenecks
    - Implementation of optimizations to improve PPA
    - Testcase development for positive, negative and corner-case scenarios


Steps to Run
------------
(Makefile in ViterbiDecoder folder. All commands to be run from here)

Sanity Test:
    make test TEST=test_Small

Run all Positive testcases (including constrained random tests), compares with golden output generated from viterbi_output_generator.py and outputs PASS/FAIL:
    make test-all

Run all Negative testcases (tests PASS if DUT throws ERROR):
    make run-negative-tests

Generate Verilog:
    make generate_verilog


To generate random testcases in random_tests folder (10 at a time, can be modified in Python script):
    cd scripts && python generate_random_viterbi_tests.py random_tests

Folder Structure
----------------

ProjectFiles
    - src            : RTL Files
    - tests          : Testcases
    - scripts        : Scripts for random test generation
    - tb             : Testbench and Golden reference generation script
    - verilog        : generate_verilog output
    - InitialBringup : Iterations for Baseline + FP Adder design

SynthesisReports
    - Final
        - 6ns reports
        - 3.96ns reports
    - Baseline
        - 6ns reports (negative slack)
        - 28.5ns reports


