; tests/alu/logic_shifts.asm
#include "../common/constants.inc"
#include "../common/passfail.inc"

    ; Setup some values
    ADDI R1, R0, 10      ; 1010
    ADDI R2, R0, 12      ; 1100

    ; --- Test 1: AND ---
    AND R3, R1, R2
    ADDI R31, R0, 8
    BNE R3, R31, test_fail

    ; --- Test 2: OR ---
    OR R4, R1, R2
    ADDI R31, R0, 14
    BNE R4, R31, test_fail

    ; --- Test 3: XOR ---
    XOR R5, R1, R2
    ADDI R31, R0, 6
    BNE R5, R31, test_fail

    ; --- Test 4: Shifts ---
    ADDI R6, R0, 1
    ADDI R7, R0, 4
    SHL R8, R6, R7
    ADDI R31, R0, 16
    BNE R8, R31, test_fail

    ADDI R9, R0, 32
    SHR R10, R9, R7
    ADDI R31, R0, 2
    BNE R10, R31, test_fail

    ; --- Test 5: Immediates ---
    ANDI R11, R1, 12
    ADDI R31, R0, 8
    BNE R11, R31, test_fail

    ORI R12, R1, 12
    ADDI R31, R0, 14
    BNE R12, R31, test_fail

    XORI R13, R1, 12
    ADDI R31, R0, 6
    BNE R13, R31, test_fail

    SHLI R14, R6, 4
    ADDI R31, R0, 16
    BNE R14, R31, test_fail

    SHRI R15, R9, 4
    ADDI R31, R0, 2
    BNE R15, R31, test_fail

    JAL R0, test_pass
