# NanoCore-64

A custom, lightweight experimental 64-bit RISC architecture optimized for area-oriented, resource-constrained applications with foundational OS primitive support.

**Author:** Aryan Kumar Mishra

## Key Features

- **64-bit Data Width** with fixed 32-bit instructions
- **32 General Purpose Registers** (R0 hardwired to zero)
- **Single-Cycle Datapath** — simplicity over clock frequency
- **Dual Privilege Modes** — User (U) and Machine (M)
- **Lightweight MMU** — 4 KB paging with Base+Bounds sandboxing
- **Timer Interrupts** — hardware timer with compare-match interrupt
- **Trap/Exception Handling** — SYSCALL, page faults, privilege violations
- **Hardware-Enforced Sandbox** — User-mode memory protection
- **No hardware multiply/divide** — offloaded to software
- **No speculative execution or branch prediction**

## Repository Structure

```
rtl/          Verilog RTL source
  cpu.v         Top-level CPU integration
  alu.v         64-bit ALU
  regfile.v     32×64-bit register file
  csr.v         Control and Status Registers
  mmu.v         Memory Management Unit
  timer.v       Hardware timer
sim/          Simulation testbench
  cpu_tb.v      RTL testbench with MMIO
tests/        Assembly test suite
  alu/          Arithmetic and logic tests
  branch/       Branch instruction tests
  csr/          CSR read/write and SYSCALL tests
  exception/    Privilege and trap tests
  memory/       Load/store tests
  mmu/          MMU translation and fault tests
  timer/        Timer interrupt tests
  common/       Shared test infrastructure
tools/        Software toolchain
  assembler.py  NanoCore-64 assembler
  emulator.py   Instruction Set Simulator
  diff_test.py  RTL ↔ Emulator differential test
  regression.py Automated regression runner
demos/        Example programs
  fibonacci.asm   Fibonacci sequence generator
  os_kernel.asm   Preemptive OS kernel demo
docs/         Documentation
  ISA.md          Instruction Set Architecture spec
  architecture.md Architecture design document
  synthesis_report.md  Yosys synthesis results
  verification.md      Verification methodology
synthesis/    Synthesis reports and logs
```

## Prerequisites

- **Python 3.x** — assembler, emulator, and test tools
- **Icarus Verilog** (`iverilog`, `vvp`) — RTL simulation
- **GTKWave** (optional) — waveform viewing
- **Yosys** (optional) — synthesis

## Quick Start

### Assemble and Emulate
```bash
python3 tools/assembler.py demos/fibonacci.asm fibonacci.hex
python3 tools/emulator.py fibonacci.hex
```

### RTL Simulation
```bash
iverilog -o cpu_sim rtl/cpu.v rtl/alu.v rtl/regfile.v rtl/csr.v rtl/mmu.v rtl/timer.v sim/cpu_tb.v
vvp cpu_sim +HEX_FILE=fibonacci.hex
```

### Run Test Suite
```bash
python3 tools/regression.py
```

### Differential Test
```bash
python3 tools/diff_test.py tests/alu/arithmetic.asm
```

## Architectural Tradeoffs

NanoCore-64 explicitly prioritizes **correctness → security → area → simplicity** over throughput:

- Single-cycle execution avoids pipeline hazards and forwarding logic
- No branch prediction eliminates speculative side channels
- Minimal MMU (Base+Bounds) vs full page-table walker reduces gate count
- Complex operations (multiply, divide) handled in software/kernel

## Current Limitations

- No sub-word (byte/halfword) load/store — only 64-bit doubleword access
- No hardware multiply/divide
- Undefined opcodes treated as NOP in RTL (no illegal instruction trap)
- Memory-mapped I/O limited to UART TX and test status ports
- MMU supports only identity mapping (M-mode) or Base+Bounds translation (U-mode)

## License

MIT License — see [LICENSE](LICENSE)
