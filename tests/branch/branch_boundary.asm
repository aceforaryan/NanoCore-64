; tests/branch/branch_boundary.asm
; Test branch edge cases: zero displacement, forward/backward, largest test

    ; Setup values
    ADDI R1, R0, 42
    ADDI R2, R0, 42
    ADDI R3, R0, 99

    ; --- Test 1: BEQ with zero displacement (target = next instruction) ---
    ; Offset = 0 means target = PC+4+0 = next sequential instruction
    BEQ  R1, R2, zero_disp
zero_disp:
    ADDI R4, R0, 1    ; Should execute whether taken or not (same address)

    ; --- Test 2: BNE not taken (equal values) ---
    BNE  R1, R2, test_fail

    ; --- Test 3: Forward branch over multiple instructions ---
    BEQ  R1, R2, forward_target
    JAL  R0, test_fail
    JAL  R0, test_fail
    JAL  R0, test_fail
forward_target:
    ADDI R5, R0, 1

    ; --- Test 4: Backward branch (loop) ---
    ADDI R6, R0, 3
loop_top:
    ADDI R6, R6, -1
    BNE  R6, R0, loop_top
    ; R6 should be 0 now
    BNE  R6, R0, test_fail

    ; --- Test 5: BNE taken with unequal values ---
    BNE  R1, R3, bne_taken
    JAL  R0, test_fail
bne_taken:

    ; --- Test 6: BEQ not taken (different values) ---
    BEQ  R1, R3, test_fail

    JAL  R0, test_pass

#include "../common/passfail.inc"
