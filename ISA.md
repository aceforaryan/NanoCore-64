# NanoCore-64 Architecture Specification

## Overview
NanoCore-64 is a powerful yet ultra-lightweight custom 64-bit RISC architecture optimized to run a full Operating System footprint (threading, GUI, wireless stacks) while minimizing gate count.

- **Data Width:** 64-bit data bus and ALU.
- **Instruction Width:** Fixed 32-bit instructions.
- **Registers:** 32 General Purpose Registers (GPRs), 64 bits wide. `R0` is hardwired to 0.
- **Privilege Modes:** User/App Mode (U) for sandboxing, and Machine Mode (M) for Kernel operations.
- **Memory Management:** Switchable hardware MMU (Translation Lookaside Buffer) for 4KB Paged Virtual Memory.
- **Interrupts/Exceptions:** Basic trap mechanism for Syscalls, Timers, and Page Faults.

## Registers
| Register | Name   | Usage |
|----------|--------|-------|
| R0       | ZERO   | Always reads 0. Writes are ignored. |
| R1       | RA     | Return Address |
| R2       | SP     | Stack Pointer |
| R3       | GP     | Global Pointer (Threads/Context) |
| R4-R31   | GPR    | General Purpose Registers |
| PC       | PC     | Program Counter (Not a GPR) |

## Instruction Formats
All instructions are 32-bit fixed width to ensure predictable multi-cycle and single-cycle decodes.

### R-Type (Register)
Used for register-to-register ALU and OS instructions.
`[Funct: 11] [Rs2: 5] [Rs1: 5] [Rd: 5] [Opcode: 6]`

### I-Type (Immediate, Load, Store, Branch, CSR)
Used for arithmetic with 16-bit constants, loads, stores, branches, and CSR access.
`[Imm: 16] [Rs1: 5] [Rd: 5] [Opcode: 6]`
*(For branches, Imm is a signed offset. For Loads/Stores, it's a signed address offset. For CSR, it's a 16-bit CSR address).*

### J-Type (Jump)
Used for long range jumps.
`[Imm: 21] [Rd: 5] [Opcode: 6]`

## Core Instruction Set (Opcodes)

| Opcode | Mnemonic | Format | Operation |
|--------|----------|--------|-----------|
| `000000`| NOP      | R      | No operation |
| `000001`| ADD      | R/I    | `Rd = Rs1 + (Rs2 or Sext(Imm))` |
| `000010`| SUB      | R      | `Rd = Rs1 - Rs2` |
| `000011`| AND      | R/I    | `Rd = Rs1 & (Rs2 or Sext(Imm))` |
| `000100`| OR       | R/I    | `Rd = Rs1 \| (Rs2 or Sext(Imm))` |
| `000101`| XOR      | R/I    | `Rd = Rs1 ^ (Rs2 or Sext(Imm))` |
| `000110`| SHL      | R/I    | `Rd = Rs1 << (Rs2 or Imm[5:0])` (Logical Left) |
| `000111`| SHR      | R/I    | `Rd = Rs1 >> (Rs2 or Imm[5:0])` (Logical Right) |
| `001000`| LD       | I      | `Rd = MEM64[Rs1 + Sext(Imm)]` (Load Double Word) |
| `001001`| ST       | I      | `MEM64[Rs1 + Sext(Imm)] = Rd` (Store Double Word) |
| `001010`| BEQ      | I      | `if (Rd == Rs1) PC = PC + 4 + Sext(Imm)<<2` |
| `001011`| BNE      | I      | `if (Rd != Rs1) PC = PC + 4 + Sext(Imm)<<2` |
| `001100`| JAL      | J      | `Rd = PC + 4; PC = PC + Sext(Imm)<<2` |
| `001101`| JALR     | I      | `Rd = PC + 4; PC = Rs1 + Sext(Imm)` |
| `001110`| CSRR     | I      | `Rd = CSR[Imm]` (CSR Read) |
| `001111`| CSRW     | I      | `CSR[Imm] = Rs1` (CSR Write) |
| `010000`| SYSCALL  | R      | Traps to Machine Mode `(Exception 0x01)` |
| `010001`| RET      | R      | Returns from Exception to previous mode |
| `111111`| SLEEP    | R      | Halts CPU execution until external interrupt. (Low power) |

> Note: Hardware multiplication and division are excluded. Emulate via software algorithms in M-Mode or compiler libraries to maintain *ultra-lightweight* gate count.

## Control and Status Registers (CSRs)
Operated on via `CSRR/CSRW` instructions. Valid only in M-Mode.

| Address | Name      | Description |
|---------|-----------|-------------|
| `0x00`  | `STATUS`  | Contains global status bits (e.g. Interrupt Enable, Privilege Mode flag). |
| `0x01`  | `EPC`     | Exception Program Counter. Stores PC when an exception occurs. |
| `0x02`  | `CAUSE`   | Exception Cause (1=Syscall, 2=Page Fault, 3=Timer). |
| `0x03`  | `MMU_PTB` | Page Table Base address. `0` = Physical Addressing modes, non-zero enables Paged Virtual Memory. |
| `0x04`  | `TVAL`    | Trap Value (e.g. faulted virtual address on a page fault). |
