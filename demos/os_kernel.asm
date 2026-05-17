; NanoCore-64 Preemptive OS Kernel with UART MMIO
; TCB1 at 0x1000, TCB2 at 0x1100

    ; Reset / Trap Vector at 0x0000
    CSRR R31, 2
    BEQ R31, R0, boot
    JAL R0, trap_handler

boot:
    ; We need to build the UART address (0x10000000)
    ; 0x10000000 = 4096 << 16
    ADDI R20, R0, 4096
    SHLI R20, R20, 16
    
    ; Jump over threads to get their addresses
    JAL R10, thread_2_start
thread_1_start:
    ; --- THREAD 1 ('A') ---
    ADDI R1, R0, 65     ; ASCII 'A'
t1_loop:
    ST R1, R20, 0       ; Write to UART
    ; Delay loop
    ADDI R2, R0, 10
t1_delay:
    ADDI R2, R2, -1
    BNE R2, R0, t1_delay
    JAL R0, t1_loop

thread_2_start:
    ; R10 has address of thread_1_start. We jump over thread_2 to skip it
    JAL R11, kernel_init
    
    ; --- THREAD 2 ('B') ---
    ADDI R1, R0, 66     ; ASCII 'B'
t2_loop:
    ST R1, R20, 0       ; Write to UART
    ; Delay loop
    ADDI R2, R0, 10
t2_delay:
    ADDI R2, R2, -1
    BNE R2, R0, t2_delay
    JAL R0, t2_loop

kernel_init:
    ; R10 = thread 1 PC, R11 = thread 2 PC
    
    ; Initialize TCB1 (0x1000)
    ADDI R5, R0, 4096   ; 0x1000
    ; EPC offset is 32 * 8 = 256
    ST R10, R5, 256     ; Store Thread 1 PC into TCB1 EPC slot
    
    ; Initialize TCB2 (0x1100)
    ADDI R6, R0, 4352   ; 0x1100
    ST R11, R6, 256     ; Store Thread 2 PC into TCB2 EPC slot
    
    ; We use R30 in kernel to keep track of current thread (1 or 2)
    ADDI R30, R0, 1
    
    ; Set EPC to Thread 1 to start
    CSRW 1, R10
    
    ; Set up Timer for first interrupt
    CSRR R12, 5         ; Read TIME
    ADDI R13, R0, 100   ; 100 cycles slice
    ADD R14, R12, R13
    CSRW 6, R14         ; Set TIMECMP
    
    ; Set up MMU Sandboxing (Limit = 1 Page, Base = 0)
    ; Value: (1 << 32) | 0
    ADDI R15, R0, 1
    SHLI R15, R15, 32
    CSRW 3, R15

    ; Enable Interrupts and drop to User Mode (STATUS = 2)
    ADDI R4, R0, 2
    CSRW 0, R4
    
    ; Return from trap (will jump to EPC which is Thread 1, in User Mode)
    RET

trap_handler:
    ; CAUSE is in CSR 2
    CSRR R25, 2
    
    ; If not timer (3), just halt
    ADDI R26, R0, 3
    BNE R25, R26, halt

    ; --- CONTEXT SWITCH ---
    ; Which thread was running?
    ADDI R26, R0, 1
    BEQ R30, R26, save_t1
    
save_t2:
    ; We were in Thread 2, save to TCB2 (0x1100)
    ADDI R27, R0, 4352
    ; Save a few registers (e.g. R1, R2 for simplicity. Full OS saves all)
    ST R1, R27, 8
    ST R2, R27, 16
    ; Save EPC
    CSRR R28, 1
    ST R28, R27, 256
    ; Switch current thread to 1
    ADDI R30, R0, 1
    JAL R0, load_t1

save_t1:
    ; We were in Thread 1, save to TCB1 (0x1000)
    ADDI R27, R0, 4096
    ST R1, R27, 8
    ST R2, R27, 16
    CSRR R28, 1
    ST R28, R27, 256
    ; Switch current thread to 2
    ADDI R30, R0, 2
    
load_t2:
    ; Load from TCB2
    ADDI R27, R0, 4352
    LD R1, R27, 8
    LD R2, R27, 16
    LD R28, R27, 256
    CSRW 1, R28
    JAL R0, finish_switch

load_t1:
    ; Load from TCB1
    ADDI R27, R0, 4096
    LD R1, R27, 8
    LD R2, R27, 16
    LD R28, R27, 256
    CSRW 1, R28

finish_switch:
    ; Set next timer interrupt
    CSRR R12, 5
    ADDI R13, R0, 100
    ADD R14, R12, R13
    CSRW 6, R14
    
    ; Re-enable MMU Sandbox and Interrupts
    ADDI R15, R0, 1
    SHLI R15, R15, 32
    CSRW 3, R15

    ; Re-enable interrupts and User mode
    ADDI R4, R0, 2
    CSRW 0, R4
    
    RET

halt:
    SLEEP
