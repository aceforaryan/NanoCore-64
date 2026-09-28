; tests/exception/ret_to_user.asm
; Test complete M-mode -> U-mode transition via STATUS + RET
; Then verify that U-mode code can still execute arithmetic,
; and that SYSCALL returns to M-mode.

    ; Trap vector
    CSRR R31, 2
    BEQ  R31, R0, boot

trap_handler:
    CSRR R10, 2
    ADDI R11, R0, 1
    BEQ  R10, R11, handle_syscall

    ; Any other trap = fail
    JAL  R0, test_fail

handle_syscall:
    ; Read EPC, skip past SYSCALL
    CSRR R12, 1
    ADDI R12, R12, 4
    CSRW 1, R12

    ; Stay in M-mode (STATUS=1)
    ADDI R13, R0, 1
    CSRW 0, R13

    ; Clear CAUSE
    CSRW 2, R0

    RET

boot:
    ; Set PTB for U-mode: limit=64, base=0 (identity mapping)
    ADDI R1, R0, 64
    SHLI R1, R1, 32
    CSRW 3, R1

    ; Switch to User mode: STATUS=0 (U-mode, GIE=0)
    ADDI R2, R0, 0
    CSRW 0, R2

    ; Now in User mode
    ; Execute some arithmetic
    ADDI R3, R0, 10
    ADDI R4, R0, 20
    ADD  R5, R3, R4
    ADDI R6, R0, 30
    BNE  R5, R6, escape_fail

    ; Return to M-mode via SYSCALL
    SYSCALL

    ; Back in M-mode, verify R5 is still 30
    ADDI R7, R0, 30
    BNE  R5, R7, test_fail

    JAL  R0, test_pass

escape_fail:
    SYSCALL
    JAL  R0, test_fail

#include "../common/passfail.inc"
