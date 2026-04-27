# NanoCore-64 Architecture Specification

## Overview
NanoCore-64 is a powerful yet ultra-lightweight custom 64-bit RISC architecture optimized to run a full Operating System footprint (threading, GUI, wireless stacks) while minimizing gate count.

- **Data Width:** 64-bit data bus and ALU.
- **Instruction Width:** Fixed 32-bit instructions.
- **Registers:** 32 General Purpose Registers (GPRs), 64 bits wide. `R0` is hardwired to 0.
- **Privilege Modes:** User/App Mode (U) for sandboxing, and Machine Mode (M) for Kernel operations.
- **Memory Management:** Switchable hardware MMU for 4KB Paged Virtual Memory.
- **Interrupts/Exceptions:** Asynchronous and Synchronous trap mechanism.

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
*(For branches, Imm is a signed label offset. For Loads/Stores/CSR, it's a signed immediate or 16-bit address).*

### J-Type (Jump)
Used for long range jumps.
`[Imm: 21] [Rd: 5] [Opcode: 6]`

## Core Instruction Set (Opcodes)

| Opcode | Mnemonic | Format | Operation |
|--------|----------|--------|-----------|
| `000000`| NOP      | R      | No operation |
| `000001`| ADD      | R      | `Rd = Rs1 + Rs2` |
| `100001`| ADDI     | I      | `Rd = Rs1 + Sext(Imm)` |
| `000010`| SUB      | R      | `Rd = Rs1 - Rs2` |
| `000011`| AND      | R      | `Rd = Rs1 & Rs2` |
| `100011`| ANDI     | I      | `Rd = Rs1 & Sext(Imm)` |
| `000100`| OR       | R      | `Rd = Rs1 | Rs2` |
| `100100`| ORI      | I      | `Rd = Rs1 | Sext(Imm)` |
| `001000`| LD       | I      | `Rd = MEM64[Rs1 + Sext(Imm)]` (Load Double Word) |
| `001001`| ST       | I      | `MEM64[Rs1 + Sext(Imm)] = Rd` (Store Double Word) |
| `001010`| BEQ      | I      | `if (Rd == Rs1) PC = PC + 4 + Sext(Imm)<<2` (Offset is relative to PC+4) |
| `001011`| BNE      | I      | `if (Rd != Rs1) PC = PC + 4 + Sext(Imm)<<2` |
| `001100`| JAL      | J      | `Rd = PC + 4; PC = PC + 4 + Sext(Imm)<<2` |
| `001101`| JALR     | I      | `Rd = PC + 4; PC = Rs1 + Sext(Imm)` |
| `001110`| CSRR     | I      | `Rd = CSR[Imm]` (CSR Read) |
| `001111`| CSRW     | I      | `CSR[Imm] = Rs1` (CSR Write) |
| `010000`| SYSCALL  | R      | Traps to Machine Mode `(Cause 1)` |
| `010001`| RET      | R      | Returns to previous mode and `EPC` address |
| `111111`| SLEEP    | R      | Halts CPU execution until interrupt. |

## Control and Status Registers (CSRs)
Operated on via `CSRR/CSRW` instructions. Valid only in M-Mode.

| Address | Name      | Description |
|---------|-----------|-------------|
| `0x00`  | `STATUS`  | `[1]` Global Interrupt Enable (GIE), `[0]` Privilege Mode (1=M, 0=U) |
| `0x01`  | `EPC`     | Exception Program Counter. Stores PC of faulting instruction. |
| `0x02`  | `CAUSE`   | Exception Cause (1=Syscall, 2=Page Fault, 3=Timer). |
| `0x03`  | `MMU_PTB` | Page Table Base. If > 0, enables translation in U-Mode. |
| `0x04`  | `TVAL`    | Trap Value (e.g. faulted virtual address). |
| `0x05`  | `TIME`    | Current 64-bit cycle counter (Read-only). |
| `0x06`  | `TIMECMP` | Timer Comparison register for creating interrupts. |

## Memory Management Unit (MMU)
When `MMU_PTB > 0` and `STATUS[0] == 0` (User Mode):
- **Address Translation:** `PhysicalAddr = ((VPN + PTB) << 12) | Offset`.
- **Protection:** Access to physical addresses `< 0x10000` (64KB Kernel Protected Zone) triggers a Page Fault.
- **Transparency:** The MMU is transparent in Machine Mode (`STATUS[0] == 1`).
