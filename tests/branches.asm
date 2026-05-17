; NanoCore-64 ISA Test Suite: Branches
; Test Categories: taken/not-taken, negative offsets, edge jumps

    ADDI R1, R0, 10
    ADDI R2, R0, 10
    ADDI R3, R0, 20

    ; --- Test 1: Taken BEQ ---
    BEQ R1, R2, target_taken
    ADDI R4, R0, 99     ; Should not execute
target_taken:
    ADDI R4, R0, 1      ; R4 = 1

    ; --- Test 2: Not-Taken BEQ ---
    BEQ R1, R3, target_fail
    ADDI R5, R0, 1      ; R5 = 1 (should execute)

    ; --- Test 3: Taken BNE ---
    BNE R1, R3, target_bne_taken
    ADDI R6, R0, 99     ; Should not execute
target_bne_taken:
    ADDI R6, R0, 1      ; R6 = 1

    ; --- Test 4: Not-Taken BNE ---
    BNE R1, R2, target_fail
    ADDI R7, R0, 1      ; R7 = 1 (should execute)

    ; --- Test 5: Negative Offset (Backwards jump) ---
    ADDI R8, R0, 2
loop_start:
    ADDI R8, R8, -1
    BNE R8, R0, loop_start  ; Jumps back until R8 == 0

    JAL R0, end_test
    
target_fail:
    ; Fail state
    ADDI R31, R0, -1
    SLEEP

end_test:
    SLEEP
