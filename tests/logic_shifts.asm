; NanoCore-64 Exhaustive ALU Test: Logic and Shifts

    ; Setup some values
    ADDI R1, R0, 10      ; 1010 in binary
    ADDI R2, R0, 12      ; 1100 in binary

    ; --- Test 1: AND ---
    AND R3, R1, R2      ; 1010 & 1100 = 1000 (8)
    ; Expected: R3 == 8

    ; --- Test 2: OR ---
    OR R4, R1, R2       ; 1010 | 1100 = 1110 (14)
    ; Expected: R4 == 14

    ; --- Test 3: XOR ---
    XOR R5, R1, R2      ; 1010 ^ 1100 = 0110 (6)
    ; Expected: R5 == 6

    ; --- Test 4: Shifts ---
    ADDI R6, R0, 1
    ADDI R7, R0, 4
    SHL R8, R6, R7      ; 1 << 4 = 16
    ; Expected: R8 == 16

    ADDI R9, R0, 32
    SHR R10, R9, R7     ; 32 >> 4 = 2
    ; Expected: R10 == 2

    ; --- Test 5: Immediates ---
    ANDI R11, R1, 12     ; 1010 & 1100 = 1000 (8)
    ; Expected: R11 == 8

    ORI R12, R1, 12      ; 1010 | 1100 = 1110 (14)
    ; Expected: R12 == 14

    XORI R13, R1, 12     ; 1010 ^ 1100 = 0110 (6)
    ; Expected: R13 == 6

    SHLI R14, R6, 4      ; 1 << 4 = 16
    ; Expected: R14 == 16

    SHRI R15, R9, 4      ; 32 >> 4 = 2
    ; Expected: R15 == 2

    SLEEP
