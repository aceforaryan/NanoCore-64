; tests/alu/arithmetic.asm
#include "../common/constants.inc"
#include "../common/passfail.inc"

    ; --- Test 1: Basic Addition (ADD) ---
    ADDI R1, R0, 10
    ADDI R2, R0, 20
    ADD  R3, R1, R2
    ADDI R4, R0, 30
    BNE  R3, R4, test_fail

    ; --- Test 2: Basic Subtraction (SUB) ---
    SUB  R4, R3, R1
    ADDI R5, R0, 20
    BNE  R4, R5, test_fail

    ; --- Test 3: Signed / Negative Addition ---
    ADDI R5, R0, -15
    ADD  R6, R4, R5
    ADDI R7, R0, 5
    BNE  R6, R7, test_fail

    ; --- Test 4: Subtraction yielding Negative ---
    SUB  R7, R1, R2
    ADDI R8, R0, -10
    BNE  R7, R8, test_fail

    ; --- Test 5: Overflow Behavior (Wrap around) ---
    ADDI R8, R0, -1
    ADDI R9, R0, 1
    ADD  R10, R8, R9
    BNE  R10, R0, test_fail
    
    ; --- Test 6: Unsigned Add/Sub ---
    SUB  R11, R8, R9
    ADDI R12, R0, -2
    BNE  R11, R12, test_fail

    JAL R0, test_pass
