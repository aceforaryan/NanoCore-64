; tests/timer/timer_disabled.asm
; Test that timer interrupt does NOT fire when GIE is disabled.
; Sets timecmp to a small value but keeps GIE=0.
; Waits several cycles and verifies no trap occurs.

    ; Trap vector
    CSRR R1, 2
    BEQ  R1, R0, boot

    ; Any trap = test failure (timer should not fire)
    JAL  R0, test_fail

boot:
    ; Read mtime
    CSRR R10, 5

    ; Set timecmp to current mtime + 3 (will be reached very soon)
    ADDI R11, R10, 3
    CSRW 6, R11

    ; STATUS = 1: M-mode=1, GIE=0 (interrupts disabled)
    ADDI R5, R0, 1
    CSRW 0, R5

    ; Execute NOPs — timer condition is met but GIE=0, so no interrupt
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
    NOP
    NOP
    NOP
    NOP
    NOP

    ; If we reach here, the timer correctly did not fire
    JAL R0, test_pass

#include "../common/passfail.inc"
