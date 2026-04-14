; Fibonacci Sequence Generator for NanoCore-16
; Calculates the first N Fibonacci numbers
; Uses R1 for n-1, R2 for n, R3 for next, R4 for counter, R5 for max

    LDI R1, 0        ; F(0) = 0
    LDI R2, 1        ; F(1) = 1
    LDI R4, 10       ; Loop max count (calculate 10 iterations)
    LDI R5, 0        ; Current count

loop:
    BEQ R4, end      ; If counter == 0, we're done
    
    ADD R3, R1, R2   ; R3 = R1 + R2
    
    ; Shift values (Synthesized MOV via ADD R, R, R0)
    ADD R1, R2, R0   ; R1 = R2
    ADD R2, R3, R0   ; R2 = R3
    
    ; Decrement counter
    LDI R6, 1
    SUB R4, R4, R6

    JMP loop

end:
    SLEEP
