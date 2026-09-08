# NanoCore-64 Instruction Set Architecture

## Overview

- **Data Width:** 64-bit
- **Instruction Width:** Fixed 32-bit
- **Registers:** 32 GPRs (64-bit). R0 is hardwired to zero.
- **Privilege Modes:** User (U, STATUS[0]=0) and Machine (M, STATUS[0]=1)
- **Memory:** 64-bit doubleword load/store only. 4 KB page granularity.
- **Endianness:** Implementation-defined (testbench uses word-addressed memory)

## Registers

| Register | Name | Usage |
|----------|------|-------|
| R0       | ZERO | Always reads 0. Writes are ignored. |
| R1       | RA   | Return Address (convention) |
| R2       | SP   | Stack Pointer (convention) |
| R3       | GP   | Global Pointer (convention) |
| R4–R31   | GPR  | General Purpose |
| PC       | —    | Program Counter (not a GPR) |

## Instruction Formats

### R-Type (Register-Register)
```
[31:21] Funct (11 bits)  [20:16] Rs2 (5)  [15:11] Rs1 (5)  [10:6] Rd (5)  [5:0] Opcode (6)
```

### I-Type (Immediate)
```
[31:16] Imm16 (16 bits)  [15:11] Rs1 (5)  [10:6] Rd (5)  [5:0] Opcode (6)
```

### J-Type (Jump)
```
[31:11] Imm21 (21 bits)  [10:6] Rd (5)  [5:0] Opcode (6)
```

## Instruction Set

| Opcode (bin) | Hex  | Mnemonic | Format | Operation |
|-------------|------|----------|--------|-----------|
| `000000`    | 0x00 | NOP      | R      | No operation |
| `000001`    | 0x01 | ADD      | R      | `Rd = Rs1 + Rs2` |
| `100001`    | 0x21 | ADDI     | I      | `Rd = Rs1 + Sext(Imm16)` |
| `000010`    | 0x02 | SUB      | R      | `Rd = Rs1 - Rs2` |
| `000011`    | 0x03 | AND      | R      | `Rd = Rs1 & Rs2` |
| `100011`    | 0x23 | ANDI     | I      | `Rd = Rs1 & Sext(Imm16)` |
| `000100`    | 0x04 | OR       | R      | `Rd = Rs1 \| Rs2` |
| `100100`    | 0x24 | ORI      | I      | `Rd = Rs1 \| Sext(Imm16)` |
| `000101`    | 0x05 | XOR      | R      | `Rd = Rs1 ^ Rs2` |
| `100101`    | 0x25 | XORI     | I      | `Rd = Rs1 ^ Sext(Imm16)` |
| `000110`    | 0x06 | SHL      | R      | `Rd = Rs1 << Rs2[5:0]` |
| `100110`    | 0x26 | SHLI     | I      | `Rd = Rs1 << Imm16[5:0]` |
| `000111`    | 0x07 | SHR      | R      | `Rd = Rs1 >> Rs2[5:0]` (logical) |
| `100111`    | 0x27 | SHRI     | I      | `Rd = Rs1 >> Imm16[5:0]` (logical) |
| `001000`    | 0x08 | LD       | I      | `Rd = MEM64[Rs1 + Sext(Imm16)]` |
| `001001`    | 0x09 | ST       | I      | `MEM64[Rs1 + Sext(Imm16)] = Rd` |
| `001010`    | 0x0A | BEQ      | I      | `if (Rd == Rs1) PC = PC + 4 + Sext(Imm16)<<2` |
| `001011`    | 0x0B | BNE      | I      | `if (Rd != Rs1) PC = PC + 4 + Sext(Imm16)<<2` |
| `001100`    | 0x0C | JAL      | J      | `Rd = PC + 4; PC = PC + 4 + Sext(Imm21)<<2` |
| `001101`    | 0x0D | JALR     | I      | `Rd = PC + 4; PC = Rs1 + Sext(Imm16)` |
| `001110`    | 0x0E | CSRR     | I      | `Rd = CSR[Imm16]` (M-mode only) |
| `001111`    | 0x0F | CSRW     | I      | `CSR[Imm16] = Rs1` (M-mode only) |
| `010000`    | 0x10 | SYSCALL  | R      | Trap to M-mode (Cause=1) |
| `010001`    | 0x11 | RET      | R      | `priv = STATUS[0]; PC = EPC` |
| `111111`    | 0x3F | SLEEP    | R      | Halt until interrupt |

### Undefined Opcodes

Opcodes not listed above are treated as NOP in RTL. The emulator halts on undefined opcodes. No illegal-instruction trap is generated.

## Branch and Jump Offsets

- **BEQ/BNE:** Offset is in instruction words. Target = `PC + 4 + Sext(Imm16) << 2`.
- **JAL:** Offset is in instruction words. Target = `PC + 4 + Sext(Imm21) << 2`.
- **JALR:** Target = `Rs1 + Sext(Imm16)` (byte address, not shifted).

## Control and Status Registers (CSRs)

All CSR access (CSRR/CSRW) requires Machine mode. Executing CSRR or CSRW in User mode generates a privilege violation trap (Cause=4).

| Address | Name      | Description |
|---------|-----------|-------------|
| 0x0000  | STATUS    | `[1]` Global Interrupt Enable (GIE). `[0]` Privilege Mode (1=M, 0=U). |
| 0x0001  | EPC       | Exception Program Counter. Saved on trap entry. |
| 0x0002  | CAUSE     | Trap cause code. |
| 0x0003  | MMU_PTB   | Page Table Base. `[63:32]` VPN Limit, `[31:0]` Base PPN. |
| 0x0004  | TVAL      | Trap Value (reserved for future use, currently 0). |
| 0x0005  | TIME      | Current cycle counter (read-only, reflects mtime). |
| 0x0006  | TIMECMP   | Timer compare value. Interrupt when `mtime >= TIMECMP`. |

### STATUS Register Detail

```
Bit 0: Privilege Mode — 1 = Machine, 0 = User
Bit 1: GIE — Global Interrupt Enable (1 = enabled)
Bits 63:2: Reserved
```

### Trap Cause Codes

| Code | Cause |
|------|-------|
| 0    | None (reset) |
| 1    | SYSCALL |
| 2    | Page Fault |
| 3    | Timer Interrupt |
| 4    | Privilege Violation |

## Trap Mechanism

### Trap Entry (hardware)

On any trap (SYSCALL, page fault, privilege violation, timer interrupt):
1. `EPC ← PC` (address of trapping/interrupted instruction)
2. `CAUSE ← cause code`
3. `STATUS[0] ← 1` (enter M-mode)
4. `STATUS[1] ← 0` (disable interrupts)
5. `PC ← 0x0000_0000_0000_0000` (fixed trap vector)

### Trap Return (RET instruction)

RET restores privilege from STATUS and jumps to EPC:
1. `priv_mode ← STATUS[0]`
2. `PC ← EPC`

STATUS is **not** automatically modified by RET. Software must configure STATUS (and EPC) via CSRW before executing RET.

For SYSCALL traps, the trap handler must increment EPC by 4 to skip past the SYSCALL instruction before returning.

### Interrupt Priority

In the decode stage, priority order is:
1. Timer interrupt (if enabled and pending)
2. Instruction page fault
3. Data page fault
4. Normal instruction execution

## Memory Management Unit (MMU)

### Mode Selection
- **M-mode** or **MMU_PTB == 0**: Identity mapping (virtual = physical)
- **U-mode** and **MMU_PTB != 0**: Base+Bounds translation

### PTB Format
```
[63:32] VPN Limit — maximum allowed Virtual Page Number
[31:0]  Base PPN  — physical page number offset
```

### Translation (U-mode, PTB != 0)
```
Physical Address = ((VPN + PTB[31:0]) << 12) | Offset[11:0]
```

### Protection
- If `VPN >= PTB[63:32]`, a page fault is generated
- UART address `0x10000000` is exempt from translation and bounds checking
- Both instruction fetch and data access go through the MMU

## Memory-Mapped I/O

| Address      | Name           | Description |
|-------------|----------------|-------------|
| `0x10000000` | UART TX        | Write-only. Outputs ASCII character. |
| `0x20000000` | TEST_STATUS    | Write-only. RTL testbench control. |

### TEST_STATUS Codes (testbench only)

| Value | Meaning |
|-------|---------|
| 0x00  | PASS |
| 0x01  | ASSERT_FAIL |
| 0x02  | EXCEPTION |
| 0x03  | TIMEOUT |
| 0x04  | UNKNOWN |
