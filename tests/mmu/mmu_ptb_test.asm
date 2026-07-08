; tests/mmu/mmu_ptb_test.asm
#include "../common/constants.inc"
#include "../common/passfail.inc"

    ; Reset / Trap Vector at 0x0000
    CSRR R31, 2         ; Read CAUSE
    BNE R31, R0, trap_handler
    
    ; If CAUSE == 0, proceed to boot
    JAL R0, boot

trap_handler:
    ; Check if it's a SYSCALL (CAUSE == 1)
    CSRR R10, 2
    ADDI R11, R0, 1
    BNE R10, R11, test_fail
    
    ; Switch MMU_PTB to a different base (e.g., 20)
    ADDI R12, R0, 100
    SHLI R12, R12, 32
    ORI R12, R12, 20
    CSRW 3, R12         ; Switch to Base 20
    
    ; Increment EPC by 4 to skip the SYSCALL instruction
    CSRR R13, 1
    ADDI R13, R13, 4
    CSRW 1, R13
    
    RET

boot:
    ; Step 1: Set up MMU_PTB with Base 10, Limit 100
    ADDI R1, R0, 100
    SHLI R1, R1, 32
    ORI R1, R1, 10
    CSRW 3, R1          ; MMU_PTB = Base 10, Limit 100

    ; Step 2: Drop to User Mode
    ADDI R2, R0, 0      ; User Mode, Interrupts disabled
    CSRW 0, R2

    ; Step 3: Write to Virtual Address 4096 (0x1000, VPN 1)
    ADDI R3, R0, 42
    ADDI R4, R0, 4096   ; VAddr = 0x1000
    ST R3, R4, 0        ; Store 42 at VAddr 0x1000

    ; Step 4: Call SYSCALL to switch PTB
    SYSCALL             ; This will jump to trap_handler and switch Base to 20

    ; Step 5: Read from Virtual Address 4096 again
    LD R5, R4, 0        ; Load from VAddr 0x1000

    ; Check R5 == 0 (translation switched successfully)
    BNE R5, R0, test_fail

    JAL R0, test_pass
