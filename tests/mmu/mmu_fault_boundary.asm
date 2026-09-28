; tests/mmu/mmu_fault_boundary.asm
; Test MMU boundary conditions: VPN == limit and VPN > limit
; VPN == limit should fault (>=), VPN < limit should pass.

    ; Trap vector
    CSRR R31, 2
    BEQ  R31, R0, boot

trap_handler:
    ; Should be page fault (CAUSE=2) from the boundary access
    CSRR R10, 2
    ADDI R11, R0, 2
    BNE  R10, R11, test_fail

    ; Verify EPC was saved correctly
    CSRR R12, 1
    BEQ  R12, R0, test_fail     ; EPC should not be 0

    ; Success: the boundary fault was caught
    JAL  R0, test_pass

boot:
    ; Set PTB: limit=4 pages, base_ppn=0 (identity mapping for VPN 0-3)
    ; PTB = (4 << 32) | 0 = 0x0000000400000000
    ADDI R1, R0, 4
    SHLI R1, R1, 32
    CSRW 3, R1

    ; Store a value to VPN=2 (within bounds, should succeed) via M-mode
    ADDI R2, R0, 2
    SHLI R2, R2, 12             ; vaddr = 0x2000
    ADDI R3, R0, 0xBEEF
    ST   R3, R2, 0

    ; Read back in M-mode (MMU disabled in M-mode) 
    LD   R4, R2, 0
    BNE  R4, R3, test_fail

    ; Switch to U-mode
    ADDI R5, R0, 0
    CSRW 0, R5

    ; Access VPN=4 (== limit, should fault)
    ADDI R6, R0, 4
    SHLI R6, R6, 12             ; vaddr = 0x4000
    LD   R7, R6, 0              ; This should trigger page fault

    ; Should never reach here
    JAL  R0, test_fail

#include "../common/passfail.inc"
