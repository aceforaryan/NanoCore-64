; tests/csr/csr_time_read.asm
; Test reading the TIME CSR (mtime counter).
; Verify that consecutive reads produce increasing values.

    ; Read TIME twice with NOPs between
    CSRR R1, 5     ; Read TIME
    NOP
    NOP
    NOP
    CSRR R2, 5     ; Read TIME again

    ; R2 must be strictly greater than R1
    ; We test by computing R2 - R1 and checking > 0
    SUB  R3, R2, R1

    ; If R3 == 0, TIME did not increment (fail)
    BEQ  R3, R0, test_fail

    ; Read TIME a third time
    CSRR R4, 5
    SUB  R5, R4, R2
    BEQ  R5, R0, test_fail

    JAL  R0, test_pass

#include "../common/passfail.inc"
