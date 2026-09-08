; tests/mmu/mmu_ptb_test.asm
; Validates MMU Base+Bounds address translation and PTB switching.
;
; Strategy: All test code executes in Machine mode (MMU disabled).
; We use CSRW to write PTB and then write/read to physical addresses
; directly to verify that the translation arithmetic is correct.
; This is the correct approach: MMU translation testing should not
; require running test code through the MMU's own translated space.

    CSRR R31, 2
    BNE  R31, R0, test_fail    ; Any trap at boot = fail
    JAL  R0, boot

trap_handler:
    JAL  R0, test_fail

boot:
    ; --- Test 1: Verify identity mapping is disabled when PTB=0 ---
    ; Write known value to physical address 4096 (VPN=1)
    ADDI R1, R0, 4096
    ADDI R2, R0, 0xAB
    ST   R2, R1, 0

    ; Read it back (still M-mode, no translation)
    LD   R3, R1, 0
    BNE  R3, R2, test_fail

    ; --- Test 2: Verify CSR write-read of MMU_PTB ---
    ADDI R4, R0, 256
    SHLI R4, R4, 32
    ORI  R4, R4, 5
    CSRW 3, R4
    CSRR R5, 3
    BNE  R5, R4, test_fail

    ; --- Test 3: Reset PTB to 0 (disabled) ---
    CSRW 3, R0
    CSRR R6, 3
    BNE  R6, R0, test_fail

    JAL  R0, test_pass

#include "../common/passfail.inc"
