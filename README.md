# NanoCore-64 Architecture

NanoCore-64 is a custom, lightweight experimental architecture optimized for area-oriented, resource-constrained applications. It is designed to be a simpler alternative to modern RISC-V implementations while supporting foundational OS primitives.

## Key Features
- **64-bit Data Width**: Enables wide data manipulation.
- **Fixed 32-bit Instructions**: Simple and predictable decoding.
- **32 General Purpose Registers**: Efficiency for software execution.
- **Dual Privilege Modes**: Support for User (App) and Machine (Kernel) levels.
- **Lightweight MMU**: Hardware virtual memory with 4KB paging and Base+Bounds sandboxing.
- **Foundational OS Primitives**: Support for context switching, timer interrupts, and trap handling.
- **Security**: Hardware-enforced sandbox limits for User-mode applications.

## Architectural Tradeoffs
- Single-cycle datapath prioritizes simplicity over clock frequency
- No hardware multiply/divide units
- No speculative execution or branch prediction
- Minimal address translation/protection model
- Area efficiency prioritized over peak throughput

## Repository Structure
- `rtl/`: Verilog RTL source code
  - `cpu.v`: Top-level core integration.
  - `alu.v`: 64-bit Arithmetic Logic Unit.
  - `regfile.v`: 32x64-bit Register File.
  - `csr.v`: Control and Status Registers.
  - `mmu.v`: Memory Management Unit.
  - `timer.v`: Timer and Interrupt module.
- `sim/`: Simulation files (e.g., `cpu_tb.v`).
- `tests/`: Assembly tests for verification.
- `docs/`: Documentation.
  - `ISA.md`: Full Instruction Set Architecture specification.
  - `synthesis_report.md`: Synthesis metrics and gate counts.
  - `architecture.md`: Detailed architecture design notes.
- `benchmarks/`: Performance and area comparison.
- `tools/`: Software toolchain.
  - `assembler.py`: Custom assembler for NanoCore-64 ISA.
  - `emulator.py`: Python-based instruction set simulator.
- `demos/`: Demonstration programs (e.g., `os_kernel.asm`).
- `synthesis/`: Yosys synthesis logs (`yosys_nanocore64.log`, `yosys_picorv32.log`).

## Getting Started

### Prerequisites
- Python 3.x (for assembler and emulator)
- Icarus Verilog / GTKWave (for RTL simulation)

### Assembly and Emulation
To assemble and run a program in the emulator:
```bash
python3 tools/assembler.py demos/os_kernel.asm os_kernel.hex
python3 tools/emulator.py os_kernel.hex
```

### RTL Simulation
To run the Verilog testbench:
```bash
iverilog -o cpu_sim rtl/cpu.v rtl/alu.v rtl/regfile.v rtl/csr.v rtl/mmu.v rtl/timer.v sim/cpu_tb.v
vvp cpu_sim
```

## Strategy
NanoCore-64 achieves its lightweight footprint by offloading complex operations like multiplication and division to software emulation in the Kernel (Machine mode), significantly reducing gate count and complexity.
