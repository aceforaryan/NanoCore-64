; tests/csr/csr.asm
; Trap dispatch at PC=0
    CSRR R31, 2         ; Read CAUSE
    BNE R31, R0, trap_handler

    ; If CAUSE == 0, proceed to boot
    JAL R0, boot

trap_handler:
    ; Check CAUSE == 1 (SYSCALL)
    CSRR R10, 2
    ADDI R31, R0, 1
    BNE R10, R31, test_fail

    ; Read EPC and increment by 4 to skip SYSCALL
    CSRR R11, 1
    ADDI R11, R11, 4
    CSRW 1, R11

    ; Stay in M-mode for return (STATUS[0]=1)
    ADDI R5, R0, 1
    CSRW 0, R5

    RET

boot:
    ; --- Test 1: CSR Read/Write Correctness ---
    ADDI R1, R0, 500
    CSRW 6, R1
    CSRR R2, 6
    BNE R1, R2, test_fail

    ; --- Test 2: Trap Entry via SYSCALL ---
    SYSCALL

    ; If we return here, SYSCALL + trap handler + RET works correctly
    JAL R0, test_pass

#include "../common/passfail.inc"
