; Privilege Mode and Trap Test for NanoCore-64

; The CPU always starts execution at PC=0 (either Boot or Trap right now)
    ; Check CAUSE (CSR 2) to determine why we are at PC=0
    CSRR R10, 2
    BEQ R10, R0, boot  ; If CAUSE == 0, it is a normal boot/reset

trap_handler:
    ; It's a trap! Set a signature in R20 to indicate the trap was handled
    ADDI R20, R0, 4919 ; 4919 is 0x1337
    ; Clear the CAUSE register so future trips through PC=0 do not re-trigger trap logic
    CSRW 2, R0
    ; Increment EPC by 4 to return past the SYSCALL instruction
    CSRR R11, 1
    ADDI R12, R0, 4
    ADD R11, R11, R12
    CSRW 1, R11
    ; Return from exception (drops back to previous privilege mode and jumps to EPC)
    RET

boot:
    ; Init test state in R21
    ADDI R21, R0, 1
    
    ; Switch to User Mode
    ; STATUS CSR is at address 0. Bit 0 is 1 for Machine, 0 for User.
    ADDI R5, R0, 0     ; value 0
    CSRW 0, R5         ; Write 0 to STATUS -> Enter User Mode

    ; Now in User Mode! Update state.
    ADDI R21, R0, 2

    ; Trigger Syscall
    SYSCALL            ; Traps to M-mode (Cause=1), jumps to PC=0, runs trap_handler

    ; Returned from Trap Handler! Update state.
    ADDI R21, R0, 3

end:
    SLEEP
