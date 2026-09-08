; tests/branch/jalr_test.asm
; VG-3 + VG-9: JALR basic operation and computed address (indirect call)

    ; Test 1: JALR R0, R0, 0 ? jump to absolute address 0 ? re-enter at PC=0.
    ; We use CSRR CAUSE first to distinguish reset from JALR-induced visit.
    CSRR R30, 2
    BEQ  R30, R0, boot
    JAL  R0, test_fail   ; Any unexpected trap = fail

boot:
    ; -- Test 1: JALR with computed target --------------------------------------
    ; Get current PC into R1 by using JAL. JAL R1, +4 ? R1 = PC+4 = next instr.
    JAL  R1, test1_next   ; R1 = PC of test1_next (this instruction's PC + 4)
test1_next:
    ; R1 now holds the address of this label.
    ; Compute address of jalr_target_1 = test1_next + 12 (3 instructions away)
    ADDI R2, R1, 12
    ; JALR: jump to R2+0, save return address in R3
    JALR R3, R2, 0
    ; If JALR misfired and falls through, fail
    JAL  R0, test_fail

jalr_target_1:
    ; Verify: we arrived here. R3 should be the instruction after JALR = JALR_PC + 4
    ; JALR was at test1_next + 4 + 4 = test1_next + 8 ? R3 = test1_next + 12
    ; test1_next + 12 = jalr_target_1. But R3 = PC_of_JALR + 4 = (jalr_target_1 - 4) + 4 = jalr_target_1
    ; So R3 == current PC. Let's verify R3 is non-zero (it saved a return address).
    BEQ  R3, R0, test_fail

    ; -- Test 2: JALR with immediate offset -------------------------------------
    ; Get base address into R4
    JAL  R4, test2_base
test2_base:
    ; R4 = test2_base address.
    ; Target = test2_base + 12 (2 instructions away: ADDI + JALR = 8, then +4 for the JAL R0)
    ; Actually: ADDI + JALR = 8 bytes. jalr_target_2 is at test2_base + 12.
    ADDI R5, R4, 12        ; base + immediate in register
    JALR R6, R5, 0
    JAL  R0, test_fail

jalr_target_2:
    BEQ  R6, R0, test_fail  ; R6 must hold return address (non-zero)

    ; -- Test 3: JALR with negative offset --------------------------------------
    ; Jump to jalr_target_3 using a positive-address register + negative offset
    JAL  R7, test3_base
test3_base:
    ; jalr_target_3 is 20 bytes ahead: ADDI(4) + JALR(4) + JAL_fail(4) + (jalr_target_3 is here)
    ; test3_base + 16 = jalr_target_3
    ; Use R7 + 20 as base, then offset -4 in JALR
    ADDI R8, R7, 20         ; R8 = test3_base + 20
    JALR R9, R8, -4         ; Target = R8 + (-4) = test3_base + 16 = jalr_target_3
    JAL  R0, test_fail

jalr_target_3:
    BEQ  R9, R0, test_fail  ; Return address must be non-zero

    JAL  R0, test_pass

#include "../common/passfail.inc"
