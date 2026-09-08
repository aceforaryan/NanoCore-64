; tests/mmu/mmu_valid_fetch.asm
; VG-8: Valid MMU translated instruction fetch and data access.
;
; Runs code in User mode with identity-mapped MMU (base=0, limit=64).
; Instruction fetches through the MMU do not fault (identity mapping).
; Data ST/LD through MMU translate correctly.
;
; MMIO at 0x20000000 is NOT MMU-exempt: must be in M-mode for passfail.
; SYSCALL is used to switch back to M-mode before calling test_pass.

    ; -- Trap Vector (PC=0) ------------------------------------------------------
    CSRR R31, 2
    BEQ  R31, R0, boot

trap_handler:
    CSRR R20, 2
    ADDI R21, R0, 1
    BEQ  R20, R21, trap_syscall   ; CAUSE=1 (SYSCALL) ? expected escape
    JAL  R0, test_fail            ; Any other trap (page fault, etc.) = fail

trap_syscall:
    ; Restore M-mode: set STATUS = 1 (M-mode, GIE=0)
    ADDI R22, R0, 1
    CSRW 0, R22
    ; Advance EPC past SYSCALL
    CSRR R23, 1
    ADDI R23, R23, 4
    CSRW 1, R23
    CSRW 2, R0    ; Clear CAUSE
    RET

boot:
    ; Set PTB: limit=64 pages, base_ppn=0 (identity mapping)
    ADDI R1, R0, 64
    SHLI R1, R1, 32
    CSRW 3, R1

    ; Drop to User mode
    ADDI R2, R0, 0
    CSRW 0, R2

    ; -- User Mode ---------------------------------------------------------------
    ; Code fetches here go through the MMU (VPN=0, base=0 ? physical=0): no fault.

    ; Store 0xDEAD to vaddr 0x1000 (VPN=1, within limit=64)
    ADDI R3, R0, 0xDEAD
    ADDI R4, R0, 1
    SHLI R4, R4, 12
    ST   R3, R4, 0

    ; Load back
    LD   R5, R4, 0
    BNE  R5, R3, escape_fail

    ; Store 0xBEEF to vaddr 0x2000 (VPN=2)
    ADDI R6, R0, 0xBEEF
    ADDI R7, R0, 2
    SHLI R7, R7, 12
    ST   R6, R7, 0
    LD   R8, R7, 0
    BNE  R8, R6, escape_fail

    ; All User-mode checks passed. Escape to M-mode via SYSCALL.
    SYSCALL

    ; -- M-Mode (returned from trap_handler via RET) -----------------------------
    ; Verify data still accessible from M-mode (identity mapped, MMU disabled)
    ADDI R9, R0, 0xDEAD
    LD   R10, R4, 0
    BNE  R10, R9, test_fail

    JAL  R0, test_pass

escape_fail:
    ; Need to reach M-mode before calling test_fail
    SYSCALL
    ; After return from syscall (M-mode restored), fail
    JAL  R0, test_fail

#include "../common/passfail.inc"
