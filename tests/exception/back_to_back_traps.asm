; tests/exception/back_to_back_traps.asm
; VG-5: Back-to-back traps (two sequential SYSCALLs with intervening RET)
;
; NanoCore-64 does NOT support nested traps. There is no saved-privilege
; stack. A second SYSCALL from within a trap handler would overwrite EPC.
; This test verifies the DEFINED behavior: trap ? RET ? trap again works
; correctly when traps are sequential (not nested).
;
; Test sequence:
;   1. SYSCALL #1 ? trap (EPC=syscall1_pc, CAUSE=1) ? handler increments counter ? RET
;   2. SYSCALL #2 ? trap (EPC=syscall2_pc, CAUSE=1) ? handler increments counter ? RET
;   3. Verify counter==2 (both traps were serviced)

    ; --- Trap Vector at PC=0 ---
    CSRR R30, 2          ; Read CAUSE
    BEQ  R30, R0, boot   ; CAUSE==0 ? boot

trap_handler:
    ; Increment trap counter (R20)
    ADDI R20, R20, 1
    ; Advance EPC by 4 to skip SYSCALL
    CSRR R21, 1
    ADDI R21, R21, 4
    CSRW 1, R21
    ; Stay in M-mode for return (STATUS[0]=1)
    ADDI R22, R0, 1
    CSRW 0, R22
    ; Clear CAUSE
    CSRW 2, R0
    RET

boot:
    ADDI R20, R0, 0      ; Trap counter = 0

    ; --- SYSCALL #1 ---
    SYSCALL

    ; Handler fires, increments R20 to 1, returns here
    ADDI R1, R0, 1
    BNE  R20, R1, test_fail

    ; --- SYSCALL #2 ---
    SYSCALL

    ; Handler fires again, increments R20 to 2, returns here
    ADDI R1, R0, 2
    BNE  R20, R1, test_fail

    JAL R0, test_pass

#include "../common/passfail.inc"
