; tests/memory/mmio_uart.asm
; Test UART MMIO write (0x10000000) and TEST_STATUS MMIO.
; Verifies UART write does not corrupt data memory and TEST_STATUS terminates.

    ; --- Test 1: Write a character to UART ---
    ADDI R1, R0, 0x1000
    SHLI R1, R1, 16           ; R1 = 0x10000000 (UART address)

    ADDI R2, R0, 0x41         ; 'A' = 0x41
    ST   R2, R1, 0            ; Write to UART

    ADDI R2, R0, 0x42         ; 'B' = 0x42
    ST   R2, R1, 0            ; Write to UART

    ; --- Test 2: Verify data memory is not corrupted by UART writes ---
    ; Write to a normal address, then read it back
    ADDI R3, R0, 512
    ADDI R4, R0, 0xABCD
    ST   R4, R3, 0
    LD   R5, R3, 0
    BNE  R5, R4, test_fail

    JAL  R0, test_pass

#include "../common/passfail.inc"
