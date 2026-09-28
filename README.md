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
  cpu_tb.v      RTL testbench with MMIO and architectural trace
tests/        Assembly test suite (25 directed tests)
  alu/          Arithmetic, logic, shift, and R0 protection tests
  branch/       Branch, JALR, and boundary tests
  csr/          CSR read/write, SYSCALL, and TIME tests
  exception/    Privilege, trap, RET, and back-to-back trap tests
  memory/       Load/store and MMIO tests
  mmu/          MMU translation, fault, and boundary tests
  timer/        Timer interrupt, compare, and masking tests
  common/       Shared test infrastructure (passfail.inc)
tools/        Software toolchain
  assembler.py        NanoCore-64 assembler
  emulator.py         Instruction Set Simulator (ISS)
  diff_test.py        RTL ↔ ISS differential comparator
  test_comparator.py  Comparator fault-injection validation
  random_test.py      Seeded randomized differential testing
  regression.py       Automated regression runner
demos/        Example programs
  fibonacci.asm   Fibonacci sequence generator
  os_kernel.asm   Preemptive OS kernel demo
docs/         Documentation
  ISA.md          Instruction Set Architecture spec
  architecture.md Architecture design document
  synthesis_report.md  Yosys synthesis results
  verification.md      Verification methodology
synthesis/    Synthesis reports
Makefile      Canonical build entry point
```

## Prerequisites

- **Python 3.x** — assembler, emulator, and test tools
- **Icarus Verilog** (`iverilog`, `vvp`) — RTL simulation
- **GTKWave** (optional) — waveform viewing
- **Yosys** (optional) — synthesis

## Quick Start

### Build
```bash
make                    # Compile RTL simulation binary
```

### Run Tests
```bash
make test               # Directed regression (25 tests)
make diff               # Differential ISS/RTL comparison (25 tests)
make fuzz               # Seeded randomized differential testing (20 seeds)
make test-comparator    # Comparator fault-injection validation (20 tests)
```

### Single Test
```bash
python3 tools/assembler.py demos/fibonacci.asm fibonacci.hex
python3 tools/emulator.py fibonacci.hex
```

### RTL Simulation
```bash
make compile
vvp cpu_sim +HEX_FILE=fibonacci.hex
```

### Synthesis
```bash
make synth
```

## Verification Summary

| Metric | Result |
|--------|--------|
| Directed regression | 25/25 PASS |
| Differential ISS/RTL match | 25/25 MATCH (0 mismatches) |
| Comparator fault-injection | 20/20 faults detected |
| Randomized differential | 20/20 seeds MATCH |
| Synthesis (Yosys generic) | 18,347 cells |

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
