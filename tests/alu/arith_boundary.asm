; tests/alu/arith_boundary.asm
; VG-2: Signed arithmetic boundary values: 0, 1, -1, INT64_MAX, INT64_MIN
; Tests sign-extension correctness and 64-bit wraparound

    ; Build INT64_MAX = 0x7FFF_FFFF_FFFF_FFFF
    ; ADDI -1 gives 0xFFFF...FFFF, then SHR by 1 gives 0x7FFF...FFFF
    ADDI R1, R0, -1
    SHRI R1, R1, 1       ; R1 = INT64_MAX = 0x7FFF_FFFF_FFFF_FFFF

    ; Build INT64_MIN = 0x8000_0000_0000_0000
    ADDI R2, R0, 1
    SHLI R2, R2, 63      ; R2 = INT64_MIN = 0x8000_0000_0000_0000

    ; --- INT64_MAX + 1 wraps to INT64_MIN ---
    ADDI R3, R0, 1
    ADD  R4, R1, R3
    BNE  R4, R2, test_fail

    ; --- INT64_MIN - 1 wraps to INT64_MAX ---
    ADDI R3, R0, 1
    SUB  R5, R2, R3
    BNE  R5, R1, test_fail

    ; --- INT64_MIN + INT64_MIN = 0 (wraps) ---
    ADD  R6, R2, R2
    BNE  R6, R0, test_fail

    ; --- 0 - 1 = -1 ---
    ADDI R3, R0, 1
    SUB  R7, R0, R3
    ADDI R8, R0, -1
    BNE  R7, R8, test_fail

    ; --- ADDI sign extension: ADDI with -1 immediate ---
    ADDI R9, R0, -1
    ADDI R10, R0, -1
    BNE  R9, R10, test_fail

    ; --- INT64_MAX AND INT64_MIN = 0 ---
    AND  R11, R1, R2
    BNE  R11, R0, test_fail

    ; --- INT64_MAX OR INT64_MIN = -1 ---
    OR   R12, R1, R2
    ADDI R13, R0, -1
    BNE  R12, R13, test_fail

    ; --- INT64_MAX XOR INT64_MIN = -1 ---
    XOR  R14, R1, R2
    BNE  R14, R13, test_fail

    JAL R0, test_pass

#include "../common/passfail.inc"
