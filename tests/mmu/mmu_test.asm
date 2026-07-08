; tests/mmu/mmu_test.asm
#include "../common/constants.inc"
#include "../common/passfail.inc"

    ; Check CAUSE (CSR 2)
    CSRR R10, 2
    BEQ R10, R0, boot  ; If CAUSE == 0, go to boot.

trap_handler:
    ; PC=0 hit via Trap. Check CAUSE.
    CSRR R22, 2
    
    ; If Cause = 2 (Page Fault), successfully caught page fault.
    ADDI R24, R0, 2
    BNE R22, R24, test_fail  ; If not page fault, fail

    JAL R0, test_pass ; Page fault successfully caught!

boot:
    ; Configure MMU_PTB to non-zero (Enable VMEM)
    ADDI R5, R0, 1
    CSRW 3, R5       ; MMU_PTB = 1

    ; Switch to User Mode
    ADDI R5, R0, 0
    CSRW 0, R5       ; Write 0 to STATUS -> Enter User Mode

    ; The VERY NEXT INSTRUCTION FETCH should trigger a Page Fault!
    ; This instruction should never execute!
    JAL R0, test_fail
