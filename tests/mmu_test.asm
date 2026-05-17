; MMU Protection Test for NanoCore-64
; Starts in Machine mode. Sets up mmu_ptb, drops to user mode, causes an instruction fetch fault.

    ; Check CAUSE (CSR 2)
    CSRR R10, 2
    BEQ R10, R0, boot  ; If CAUSE == 0, go to boot.

trap_handler:
    ; PC=0 hit via Trap. Check CAUSE.
    ADDI R20, R0, 4919 ; 0x1337 signature
    
    ; Read CAUSE into R22
    CSRR R22, 2
    
    ; If Cause = 2 (Page Fault), setting R23 = 1
    ADDI R24, R0, 2
    BNE R22, R24, end_trap  ; If not page fault, jump to end
    ADDI R23, R0, 1

end_trap:
    ; We caught the fault. Instead of returning (which would just refetch and potentially fault again),
    ; we simply halt here to indicate success.
    SLEEP

boot:
    ADDI R21, R0, 1

    ; Configure MMU_PTB to non-zero (Enable VMEM)
    ADDI R5, R0, 1
    CSRW 3, R5       ; MMU_PTB = 1

    ; Switch to User Mode
    ADDI R5, R0, 0
    CSRW 0, R5       ; Write 0 to STATUS -> Enter User Mode

    ; The VERY NEXT INSTRUCTION FETCH should trigger a Page Fault!
    ; Because PC is functionally < 0x10000, we are in User Mode, and MMU is enabled.
    ; This instruction should never execute!
    ; If it does execute, we set R21 = 999 to indicate failure.
    ADDI R21, R0, 999

    SLEEP
