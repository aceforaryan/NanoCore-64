; tests/memory/memory.asm
#include "../common/constants.inc"
#include "../common/passfail.inc"

    ; Setup base address
    ADDI R1, R0, 1024

    ; --- Test 1: Aligned Memory Write/Read ---
    ADDI R2, R0, 42
    ST R2, R1, 0
    LD R3, R1, 0
    BNE R2, R3, test_fail

    ; --- Test 2: Offset Memory Access ---
    ADDI R4, R0, 84
    ST R4, R1, 8
    LD R5, R1, 8
    BNE R4, R5, test_fail

    ; --- Test 3: Unaligned Access ---
    ADDI R6, R0, 99
    ST R6, R1, 3
    LD R7, R1, 3
    BNE R6, R7, test_fail

    JAL R0, test_pass
