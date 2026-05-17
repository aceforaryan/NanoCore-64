; NanoCore-64 ISA Test Suite: CSR & Traps
; Test Categories: read/write correctness, trap entry/exit

    ; --- Test 1: CSR Read/Write Correctness ---
    ; Write to TIMECMP (CSR 6) and read back
    ADDI R1, R0, 500
    CSRW 6, R1
    CSRR R2, 6
    ; Expected: R2 == 500

    ; --- Test 2: Trap Entry via SYSCALL ---
    ; We set up EPC (CSR 1) just to verify it gets overwritten
    ADDI R3, R0, 99
    CSRW 1, R3
    
    ; Setup Trap Vector at 0x0000 (We assume we boot from 0, so we just jump to test)
    ; In this test environment, SYSCALL will jump to 0. 
    ; Let's build a mini trap handler at start.
    
    JAL R0, main_start
    
    ; Trap handler (Address ~0x0004 or 0x0008 depending on jump)
trap_handler:
    ; Read CAUSE (CSR 2)
    CSRR R10, 2
    ; Expected R10 == 1 (Syscall)
    
    ; Read EPC (CSR 1)
    CSRR R11, 1
    
    ; Exit Trap
    RET

main_start:
    ; Register trap handler by tricking boot sequence or simply causing the trap
    ; Currently NanoCore traps to 0x0. We will rely on emulator/RTL starting correctly.
    
    SYSCALL
    
    ; Expected: execution resumes here after RET
    ADDI R5, R0, 1

    SLEEP
