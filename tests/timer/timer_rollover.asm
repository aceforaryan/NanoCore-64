; tests/timer/timer_rollover.asm
; VG-7: Timer with minimum timecmp value, and verify mtime increments
;
; True 64-bit rollover (mtime wrapping 0xFFFF...->0) requires pre-loading
; mtime, which is not possible without testbench modification. This test
; instead verifies:
;   1. mtime increments each cycle (read twice, second > first)
;   2. timer fires for a very small timecmp (timecmp=2, fires almost immediately)
;   3. interrupt handler correctly receives CAUSE=3 and disables GIE
;
; Architecture note: timer rollover (mtime = 0xFFFF... + 1 = 0) is expected
; to produce 0 without interrupt if timecmp is also 0 (0 >= 0 is true).
; This edge case requires testbench support and is documented as a gap.

    CSRR R1, 2
    BEQ  R1, R0, boot
    ; Trap vector
    CSRR R22, 2
    ADDI R24, R0, 3
    BNE  R22, R24, test_fail   ; Expect CAUSE=3 (timer)
    ADDI R1, R0, 1
    CSRW 0, R1                 ; Disable interrupts (M-mode, GIE=0)
    JAL  R0, test_pass

boot:
    ; Read mtime twice, verify it increases
    CSRR R10, 5
    NOP
    NOP
    CSRR R11, 5
    BEQ  R10, R11, test_fail   ; mtime must have incremented

    ; Set TIMECMP to current mtime + 2 (fires almost instantly)
    ADDI R12, R0, 2
    ADD  R12, R11, R12
    CSRW 6, R12

    ; Enable interrupts (STATUS = 3: M-mode=1, GIE=1)
    ADDI R5, R0, 3
    CSRW 0, R5

    SLEEP

#include "../common/passfail.inc"
