# NanoCore-64 Architecture

NanoCore-64 is a custom, ultra-lightweight 64-bit RISC architecture optimized for low-power, high-performance applications like wearables and IoT devices. It is designed to be lighter than modern RISC-V implementations while supporting modern OS features.

## Key Features
- **64-bit Data Width**: Optimized for high-resolution graphics and complex sensor fusion.
- **Fixed 32-bit Instructions**: Simple and predictable decoding.
- **32 General Purpose Registers**: High efficiency for C compilers and OS kernels.
- **Dual Privilege Modes**: Support for User (App) and Machine (Kernel) levels.
- **Lightweight MMU**: Hardware-accelerated virtual memory with 4KB paging.
- **OS Support**: Built-in trap logic for syscalls, page faults, and hardware interrupts.

## Repository Structure
- `src/`: Verilog RTL source code and simulation tools.
  - `cpu.v`: Top-level core integration.
  - `alu.v`: 64-bit Arithmetic Logic Unit.
  - `regfile.v`: 32x64-bit Register File.
  - `csr.v`: Control and Status Registers.
  - `mmu.v`: Memory Management Unit.
  - `assembler.py`: Custom assembler for NanoCore-64 ISA.
  - `emulator.py`: Python-based instruction set simulator.
- `ISA.md`: Full Instruction Set Architecture specification.

## Getting Started

### Prerequisites
- Python 3.x (for assembler and emulator)
- Icarus Verilog / GTKWave (for RTL simulation)

### Assembly and Emulation
To assemble and run a program in the emulator:
```bash
python3 src/assembler.py program.asm program.hex
python3 src/emulator.py program.hex
```

### RTL Simulation
To run the Verilog testbench:
```bash
iverilog -o cpu_sim src/cpu.v src/alu.v src/regfile.v src/csr.v src/mmu.v src/cpu_tb.v
vvp cpu_sim
```

## Strategy
NanoCore-64 achieves its lightweight footprint by offloading complex operations like multiplication and division to software emulation in the Kernel (Machine mode), significantly reducing gate count and power consumption.
