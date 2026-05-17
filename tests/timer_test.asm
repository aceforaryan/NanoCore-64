; Timer and External Interrupts Verification Test

    ; PC=0: Initial Boot or Trap Vector
    ; Read CAUSE (CSR 2)
    CSRR R1, 2
    BEQ R1, R0, boot  ; If CAUSE == 0, we are branching to boot

trap_handler:
    ; We are here because of a trap!
    ; Check if CAUSE is 3 (Timer Interrupt)
    CSRR R22, 2
    ADDI R24, R0, 3
    BNE R22, R24, loop_fail
    
    ; Write Magic Signature indicating Timer Interrupt Successfully handled
    ADDI R20, R0, 4919 ; 0x1337.

    ; Disable interrupts by writing 1 to STATUS (M-mode, GIE=0)
    ADDI R5, R0, 1
    CSRW 0, R5

    ; Success exit
    SLEEP

loop_fail:
    ADDI R21, R0, 999
    SLEEP

boot:
    ; Record that we began execution
    ADDI R21, R0, 1

    ; Read current mtime (CSR 5)
    CSRR R10, 5
    
    ; Set timecmp to mtime + 50 cycles
    ADDI R11, R0, 50
    ADD R12, R10, R11
    
    ; Write to TIMECMP (CSR 6)
    CSRW 6, R12

    ; Give us a moment to sleep
    ; Enable Interrupts (Write 3 to STATUS -> M-Mode=1, GIE=1)
    ADDI R5, R0, 3
    CSRW 0, R5

    ; CPU should now enter low-power sleep mode and halt the pipeline.
    ; Exactly 50 cycles later, the hardware timer will assert the interrupt line,
    ; waking up the CPU, triggering a trap, and sending PC back to 0!
    SLEEP
