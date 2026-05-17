; NanoCore-64 ISA Test Suite: Memory
; Test Categories: aligned access, misaligned access, bounds violations
; Note: Current NanoCore-64 memory model might not explicitly catch misaligned access
; depending on CPU.v implementation, but we test the behavior.

    ; Setup base address
    ADDI R1, R0, 1024   ; Base address at 1KB (Aligned)

    ; --- Test 1: Aligned Memory Write/Read ---
    ADDI R2, R0, 42
    ST R2, R1, 0        ; Store 42 at address 1024
    LD R3, R1, 0        ; Load from address 1024
    ; Expected: R3 == 42

    ; --- Test 2: Offset Memory Access ---
    ADDI R4, R0, 84
    ST R4, R1, 8        ; Store 84 at address 1032
    LD R5, R1, 8        ; Load from 1032
    ; Expected: R5 == 84

    ; --- Test 3: Unaligned Access (Behavioral Check) ---
    ; In many simple RISC, this ignores bottom bits or causes fault.
    ADDI R6, R0, 99
    ST R6, R1, 3        ; Store at 1027 (Misaligned)
    LD R7, R1, 3        ; Load from 1027
    ; Expected: R7 depends on RTL (ideally triggers exception or masks bits)

    ; --- Test 4: Bounds Violations (Tested properly with MMU) ---
    ; A pure physical memory bounds violation might wrap or access garbage.

    SLEEP
