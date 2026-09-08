; tests/csr/csr_write_read.asm
; VG-6: CSR write followed immediately by CSR read (same cycle boundary)
; Also tests: CSRR in M-mode succeeds, CSRW?CSRR consistency

    ; --- Test 1: Write TIMECMP, immediately read it back ---
    ADDI R1, R0, 0x1234
    CSRW 6, R1
    CSRR R2, 6
    BNE  R2, R1, test_fail

    ; --- Test 2: Write EPC, read back ---
    ADDI R3, R0, 0x100
    CSRW 1, R3
    CSRR R4, 1
    BNE  R4, R3, test_fail

    ; --- Test 3: Write CAUSE, read back ---
    ADDI R5, R0, 7
    CSRW 2, R5
    CSRR R6, 2
    BNE  R6, R5, test_fail

    ; --- Test 4: Write MMU_PTB, read back ---
    ADDI R7, R0, 0x42
    CSRW 3, R7
    CSRR R8, 3
    BNE  R8, R7, test_fail

    ; --- Test 5: Overwrite TIMECMP with new value ---
    ADDI R9, R0, 0x5678
    CSRW 6, R9
    CSRR R10, 6
    BNE  R10, R9, test_fail

    ; --- Test 6: Write STATUS (stay in M-mode: bit0=1, GIE=0) ---
    ADDI R11, R0, 1
    CSRW 0, R11
    CSRR R12, 0
    BNE  R12, R11, test_fail

    ; --- Test 7: Write R0?TIMECMP (should write 0) ---
    CSRW 6, R0
    CSRR R13, 6
    BNE  R13, R0, test_fail

    JAL R0, test_pass

#include "../common/passfail.inc"
