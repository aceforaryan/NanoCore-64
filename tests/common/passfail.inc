; tests/common/passfail.inc
; Standard routines to terminate tests with PASS or FAIL

#include "constants.inc"

; ---------------------------------------------------------
; Routine: test_pass
; Call this when all assertions pass.
; ---------------------------------------------------------
test_pass:
    ; Construct TEST_STATUS_ADDR (0x20000000)
    ADDI R1, R0, 0x2000
    SHLI R1, R1, 16
    
    ; Write TEST_PASS (0x00)
    ADDI R2, R0, TEST_PASS
    ST R2, R1, 0
    SLEEP

; ---------------------------------------------------------
; Routine: test_fail
; Jump here when an assertion fails.
; ---------------------------------------------------------
test_fail:
    ; Construct TEST_STATUS_ADDR (0x20000000)
    ADDI R1, R0, 0x2000
    SHLI R1, R1, 16
    
    ; Write TEST_ASSERT_FAIL (0x01)
    ADDI R2, R0, TEST_ASSERT_FAIL
    ST R2, R1, 0
    SLEEP

; ---------------------------------------------------------
; Routine: test_exception
; Generic handler for unexpected exceptions.
; ---------------------------------------------------------
test_exception:
    ADDI R1, R0, 0x2000
    SHLI R1, R1, 16
    ADDI R2, R0, TEST_EXCEPTION
    ST R2, R1, 0
    SLEEP
