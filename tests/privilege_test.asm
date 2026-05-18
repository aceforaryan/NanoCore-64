; NanoCore-64 Privilege Violation Test
; Verifies that User Mode cannot write to CSRs and triggers a fault.

    ; Reset / Trap Vector at 0x0000
    CSRR R31, 2         ; Read CAUSE
    BNE R31, R0, trap_handler
    
    ; If CAUSE == 0, proceed to boot
    JAL R0, boot

trap_handler:
    ; We expect CAUSE to be 4 (Privilege Violation)
    CSRR R10, 2
    ADDI R11, R0, 4
    BNE R10, R11, fail
    
    ; Record success in R20
    ADDI R20, R0, 42    ; Magic success number
    SLEEP

fail:
    ADDI R20, R0, 99    ; Fail number
    SLEEP

boot:
    ; Step 1: Initialize TIMECMP to a known value in Machine Mode
    ADDI R1, R0, 100
    CSRW 6, R1

    ; Step 2: Drop to User Mode
    ; STATUS (CSR 0) bit 0 is Privilege Mode. Set to 0.
    ADDI R2, R0, 0
    CSRW 0, R2

    ; Step 3: Attempt to write to TIMECMP in User Mode
    ADDI R3, R0, 500
    CSRW 6, R3      ; This should trigger a trap with CAUSE = 4!

    ; If we reach here, the trap didn't happen!
    ADDI R20, R0, 999   ; Fail number (no trap)
    SLEEP
