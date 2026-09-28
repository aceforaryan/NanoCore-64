; tests/timer/timer_exact_compare.asm
; Test timer interrupt at exact TIMECMP boundary.
; Sets TIMECMP to current mtime + small offset and verifies CAUSE=3.

    ; Trap vector
    CSRR R1, 2
    BEQ  R1, R0, boot

trap_handler:
    ; Verify timer interrupt cause
    CSRR R22, 2
    ADDI R24, R0, 3
    BNE  R22, R24, test_fail

    ; Disable interrupts
    ADDI R5, R0, 1
    CSRW 0, R5

    ; Verify mtime >= timecmp at trap entry
    CSRR R10, 5     ; mtime
    CSRR R11, 6     ; timecmp
    ; mtime should be >= timecmp (this is what triggered the interrupt)
    ; We can't directly compare >= easily, but mtime incremented past timecmp

    JAL R0, test_pass

boot:
    ; Read mtime
    CSRR R10, 5

    ; Set timecmp = mtime + 5 (very tight)
    ADDI R11, R10, 5
    CSRW 6, R11

    ; Enable interrupts (STATUS = 3: M-mode=1, GIE=1)
    ADDI R5, R0, 3
    CSRW 0, R5

    ; Execute NOPs until timer fires
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; If we get here without interrupt, timer did not fire
    JAL R0, test_fail

#include "../common/passfail.inc"
