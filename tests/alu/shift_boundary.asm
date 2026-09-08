; tests/alu/shift_boundary.asm
; VG-1: Shift by 0, 1, 31, 32, 63 (SHL/SHR/SHLI/SHRI)
; VG-4: NOP exercised here

    ; Baseline
    ADDI R1, R0, 1

    ; --- SHL by 0 (no change) ---
    ADDI R2, R0, 0
    SHL  R3, R1, R2
    BNE  R3, R1, test_fail

    ; --- NOP (VG-4) ---
    NOP
    NOP

    ; --- SHL by 1 ---
    ADDI R2, R0, 1
    SHL  R3, R1, R2
    ADDI R4, R0, 2
    BNE  R3, R4, test_fail

    ; --- SHL by 31 ---
    ADDI R2, R0, 31
    SHL  R3, R1, R2
    ADDI R4, R0, 1
    SHLI R4, R4, 31
    BNE  R3, R4, test_fail

    ; --- SHL by 32 ---
    ADDI R2, R0, 32
    SHL  R3, R1, R2
    ADDI R4, R0, 1
    SHLI R4, R4, 32
    BNE  R3, R4, test_fail

    ; --- SHL by 63 ---
    ADDI R2, R0, 63
    SHL  R3, R1, R2
    ADDI R4, R0, 1
    SHLI R4, R4, 63
    BNE  R3, R4, test_fail

    ; --- SHR by 0 ---
    ADDI R5, R0, 1
    SHLI R5, R5, 63    ; R5 = 0x8000...0000
    ADDI R2, R0, 0
    SHR  R6, R5, R2
    BNE  R6, R5, test_fail

    ; --- SHR by 63 ---
    ADDI R2, R0, 63
    SHR  R7, R5, R2
    ADDI R8, R0, 1
    BNE  R7, R8, test_fail

    ; --- SHLI by 0 (immediate) ---
    ADDI R9, R0, 42
    SHLI R10, R9, 0
    BNE  R10, R9, test_fail

    ; --- SHRI by 1 ---
    ADDI R11, R0, 8
    SHRI R12, R11, 1
    ADDI R13, R0, 4
    BNE  R12, R13, test_fail

    JAL R0, test_pass

#include "../common/passfail.inc"
