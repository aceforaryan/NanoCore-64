; tests/csr/csr.asm
#include "../common/constants.inc"
#include "../common/passfail.inc"

    ; --- Test 1: CSR Read/Write Correctness ---
    ADDI R1, R0, 500
    CSRW 6, R1
    CSRR R2, 6
    
    BNE R1, R2, test_fail

    ; --- Test 2: Trap Entry via SYSCALL ---
    ADDI R3, R0, 99
    CSRW 1, R3
    
    JAL R0, main_start
    
trap_handler:
    ; Read CAUSE (CSR 2)
    CSRR R10, 2
    ADDI R31, R0, 1
    BNE R10, R31, test_fail
    
    ; Read EPC (CSR 1)
    CSRR R11, 1
    
    RET

main_start:
    SYSCALL
    
    JAL R0, test_pass
