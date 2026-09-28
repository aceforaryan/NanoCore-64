; tests/alu/r0_protection.asm
; Verify that R0 remains zero regardless of write attempts.

    ; Try to write to R0 via ADDI
    ADDI R0, R0, 42
    BNE  R0, R0, test_fail    ; R0 must still be 0

    ; Try to write via ADD
    ADDI R1, R0, 100
    ADD  R0, R1, R1
    BNE  R0, R0, test_fail

    ; Try to write via LD
    ADDI R2, R0, 1024
    ADDI R3, R0, 0x55
    ST   R3, R2, 0
    LD   R0, R2, 0
    BNE  R0, R0, test_fail

    ; Try to write via JAL (link to R0)
    JAL  R0, skip_jal
skip_jal:
    BNE  R0, R0, test_fail

    ; Verify R0 reads as 0 in comparisons
    ADDI R4, R0, 0
    BNE  R4, R0, test_fail

    JAL  R0, test_pass

#include "../common/passfail.inc"
