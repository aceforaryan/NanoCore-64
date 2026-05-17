; NanoCore-64 ISA Test Suite: Arithmetic
; Test Categories: ADD, SUB, Overflow behavior, Signed/Unsigned behavior

    ; --- Test 1: Basic Addition (ADD) ---
    ADDI R1, R0, 10
    ADDI R2, R0, 20
    ADD  R3, R1, R2   ; Expected: R3 = 30

    ; --- Test 2: Basic Subtraction (SUB) ---
    SUB  R4, R3, R1   ; Expected: R4 = 20

    ; --- Test 3: Signed / Negative Addition ---
    ; Immediate is sign-extended. ADDI with negative immediate.
    ADDI R5, R0, -15  ; R5 = -15
    ADD  R6, R4, R5   ; Expected: R6 = 20 + (-15) = 5

    ; --- Test 4: Subtraction yielding Negative ---
    SUB  R7, R1, R2   ; Expected: R7 = 10 - 20 = -10

    ; --- Test 5: Overflow Behavior (Wrap around) ---
    ; NanoCore-64 ignores overflow, wrapping around modulo 2^64
    ; We can test 64-bit wrap around by creating -1 and adding 1
    ADDI R8, R0, -1   ; R8 = 0xFFFFFFFFFFFFFFFF (all 1s)
    ADDI R9, R0, 1
    ADD  R10, R8, R9  ; Expected: R10 = 0 (wrap around)
    
    ; --- Test 6: Unsigned Add/Sub ---
    ; At the hardware level (ALU), signed and unsigned add/sub are identical
    ; in two's complement. This just verifies large positive values.
    ; R8 (-1) can be interpreted as Max Unsigned 64-bit Integer.
    SUB  R11, R8, R9  ; Expected: R11 = 0xFFFFFFFFFFFFFFFE

    SLEEP             ; End of test
