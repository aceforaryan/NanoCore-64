; tests/exception/privilege_test.asm
#include "../common/constants.inc"
#include "../common/passfail.inc"

    ; Reset / Trap Vector at 0x0000
    CSRR R31, 2         ; Read CAUSE
    BNE R31, R0, trap_handler
    
    ; If CAUSE == 0, proceed to boot
    JAL R0, boot

trap_handler:
    ; We expect CAUSE to be 4 (Privilege Violation)
    CSRR R10, 2
    ADDI R11, R0, 4
    BNE R10, R11, test_fail
    
    ; Record success
    JAL R0, test_pass

boot:
    ; Step 1: Initialize TIMECMP to a known value in Machine Mode
    ADDI R1, R0, 100
    CSRW 6, R1

    ; Step 2: Drop to User Mode
    ADDI R2, R0, 0
    CSRW 0, R2

    ; Step 3: Attempt to write to TIMECMP in User Mode
    ADDI R3, R0, 500
    CSRW 6, R3      ; This should trigger a trap with CAUSE = 4!

    ; If we reach here, the trap didn't happen!
    JAL R0, test_fail
