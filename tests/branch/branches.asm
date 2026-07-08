; tests/branch/branches.asm
#include "../common/constants.inc"
#include "../common/passfail.inc"

    ADDI R1, R0, 10
    ADDI R2, R0, 10
    ADDI R3, R0, 20

    ; --- Test 1: Taken BEQ ---
    BEQ R1, R2, target_taken
    JAL R0, test_fail
target_taken:
    ADDI R4, R0, 1

    ; --- Test 2: Not-Taken BEQ ---
    BEQ R1, R3, test_fail
    ADDI R5, R0, 1

    ; --- Test 3: Taken BNE ---
    BNE R1, R3, target_bne_taken
    JAL R0, test_fail
target_bne_taken:
    ADDI R6, R0, 1

    ; --- Test 4: Not-Taken BNE ---
    BNE R1, R2, test_fail
    ADDI R7, R0, 1

    ; --- Test 5: Negative Offset (Backwards jump) ---
    ADDI R8, R0, 2
loop_start:
    ADDI R8, R8, -1
    BNE R8, R0, loop_start

    JAL R0, test_pass
