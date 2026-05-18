; NanoCore-64 MMU PTB Switching Test
; Verifies that changing MMU_PTB changes physical address mapping.

    ; Reset / Trap Vector at 0x0000
    CSRR R31, 2         ; Read CAUSE
    BNE R31, R0, trap_handler
    
    ; If CAUSE == 0, proceed to boot
    JAL R0, boot

trap_handler:
    ; Check if it's a SYSCALL (CAUSE == 1)
    CSRR R10, 2
    ADDI R11, R0, 1
    BNE R10, R11, fail
    
    ; Switch MMU_PTB to a different base (e.g., 20)
    ; Limit 100 -> 0x64. 0x64 << 32 | 20
    ADDI R12, R0, 100
    SHLI R12, R12, 32
    ORI R12, R12, 20
    CSRW 3, R12         ; Switch to Base 20
    
    ; Increment EPC by 4 to skip the SYSCALL instruction
    CSRR R13, 1
    ADDI R13, R13, 4
    CSRW 1, R13
    
    RET

fail:
    ADDI R20, R0, 99
    SLEEP

boot:
    ; Step 1: Set up MMU_PTB with Base 10, Limit 100
    ; 100 = 0x64. 0x64 << 32 | 10
    ADDI R1, R0, 100
    SHLI R1, R1, 32
    ORI R1, R1, 10
    CSRW 3, R1          ; MMU_PTB = Base 10, Limit 100

    ; Step 2: Drop to User Mode
    ADDI R2, R0, 0      ; User Mode, Interrupts disabled
    CSRW 0, R2

    ; Step 3: Write to Virtual Address 4096 (0x1000, VPN 1)
    ; With Base 10, Physical Address = (1 + 10) << 12 = 11 << 12 = 0xB000
    ADDI R3, R0, 42
    ADDI R4, R0, 4096   ; VAddr = 0x1000
    ST R3, R4, 0        ; Store 42 at VAddr 0x1000

    ; Step 4: Call SYSCALL to switch PTB
    SYSCALL             ; This will jump to trap_handler and switch Base to 20

    ; Step 5: Read from Virtual Address 4096 again
    ; With Base 20, Physical Address = (1 + 20) << 12 = 21 << 12 = 0x15000
    ; We expect to read 0 (or garbage), NOT 42!
    LD R5, R4, 0        ; Load from VAddr 0x1000

    ; Record R5 in R20 for trace checking
    ; If translation failed to switch, R20 will be 42.
    ; If success, R20 will be 0.
    ADD R20, R0, R5

    SLEEP
