; Fibonacci Sequence Generator for NanoCore-64
; Calculates the first N Fibonacci numbers
; Uses R1 for n-1, R2 for n, R3 for next, R4 for counter, R6 for constant 1

    ADDI R1, R0, 0    ; F(0) = 0
    ADDI R2, R0, 1    ; F(1) = 1
    ADDI R4, R0, 10   ; Loop max count (calculate 10 iterations)
    ADDI R6, R0, 1    ; Constant 1 for decrement

loop:
    BEQ R4, R0, end   ; If counter == 0, we're done
    
    ADD R3, R1, R2    ; R3 = R1 + R2
    
    ; Shift values
    ADD R1, R2, R0    ; R1 = R2
    ADD R2, R3, R0    ; R2 = R3
    
    ; Decrement counter
    SUB R4, R4, R6

    JAL R0, loop      ; Jump to loop

end:
    SLEEP
