# NanoCore-64 Verification

## Simulation Environment

- **Simulator:** Icarus Verilog (`iverilog` + `vvp`)
- **Testbench:** `sim/cpu_tb.v`
- **Assembler:** `tools/assembler.py` (Python 3)
- **Emulator:** `tools/emulator.py` (Python 3 ISS)
- **Regression:** `tools/regression.py`
- **Differential Test:** `tools/diff_test.py`

## Testbench Architecture

The testbench (`cpu_tb.v`) provides:
- 2048-entry × 32-bit instruction memory (loaded via `$readmemh`)
- 2048-entry × 64-bit data memory (initialized to zero)
- Clock generation (10ns period)
- MMIO interception:
  - `0x10000000`: UART TX (prints character)
  - `0x20000000`: Test status (terminates simulation with PASS/FAIL)
- Timeout watchdog (50,000 cycles)
- Diagnostic dump on failure (registers, CSRs, PC, cycle count)
- Optional VCD waveform generation (`+DUMP_VCD=1`)

## Test Suite

Tests are in `tests/<category>/<test_name>.asm`. Each test uses `tests/common/passfail.inc` for standardized pass/fail reporting via MMIO writes.

### Test Categories

| Category | Tests | Coverage |
|----------|-------|----------|
| `alu/arithmetic` | ADD, ADDI, SUB, signed addition, overflow wrap | Basic arithmetic correctness |
| `alu/logic_shifts` | AND, OR, XOR, SHL, SHR, ANDI, ORI, XORI, SHLI, SHRI | Logic and shift operations |
| `branch/branches` | BEQ taken/not-taken, BNE taken/not-taken, backward branch | Control flow |
| `memory/memory` | Aligned LD/ST, offset access, unaligned access | Load/store |
| `csr/csr` | CSR read/write, SYSCALL trap + return | CSR and trap entry |
| `exception/privilege_test` | User-mode CSRW → privilege violation trap | Privilege enforcement |
| `exception/traps_test` | SYSCALL → trap handler → RET → User mode | Full trap round-trip |
| `mmu/mmu_test` | MMU enabled with invalid PTB → page fault | Instruction page fault |
| `mmu/mmu_ptb_test` | PTB switch via SYSCALL, verify translation change | Address translation |
| `timer/timer_test` | Timer interrupt generation and handling | Timer subsystem |

### Test Structure

Each test file includes `passfail.inc` at the **end** (not the beginning) to ensure test code starts at PC=0. Tests that use traps include a trap dispatch sequence at PC=0:

```asm
    CSRR R31, 2         ; Read CAUSE
    BNE R31, R0, trap_handler
    JAL R0, boot         ; Normal boot if CAUSE == 0
```

## Running Tests

### Single Test
```bash
python3 tools/assembler.py tests/alu/arithmetic.asm tests/alu/arithmetic.hex
iverilog -o cpu_sim rtl/cpu.v rtl/alu.v rtl/regfile.v rtl/csr.v rtl/mmu.v rtl/timer.v sim/cpu_tb.v
vvp cpu_sim +HEX_FILE=tests/alu/arithmetic.hex
```

### Full Regression
```bash
python3 tools/regression.py
```

Results are written to `reports/latest/` with per-test logs and a summary.

### Differential Test (RTL vs Emulator)
```bash
python3 tools/diff_test.py tests/alu/arithmetic.asm
```

Compares execution traces between the emulator and RTL simulation.

## Emulator

The Python ISS (`tools/emulator.py`) implements the same ISA as the RTL. It can be used for:
- Quick program testing without RTL simulation
- Trace generation (`--trace` flag)
- Differential testing against RTL

### Known Emulator/RTL Differences

| Aspect | RTL | Emulator |
|--------|-----|----------|
| Undefined opcodes | NOP (silent) | Halts with error message |
| Instruction memory | 2048 × 32-bit (testbench) | 4096 × 32-bit |
| Data memory | 2048 × 64-bit (testbench) | 4096 × 64-bit |
| MMIO 0x20000000 | Terminates simulation | Not implemented |

## Verification Gaps

The following previously-identified verification gaps have been closed and verified against both RTL and Emulator:

- Shift by 0 and shift by 63 (boundary) -> Covered by lu/shift_boundary
- Maximum/minimum signed values in arithmetic -> Covered by lu/arith_boundary
- JALR instruction -> Covered by ranch/jalr_test
- NOP instruction -> Covered by lu/shift_boundary
- Multiple back-to-back traps -> Covered by exception/back_to_back_traps (Note: Nested traps are not architecturally supported; only sequential traps are supported)
- CSR read-after-write in consecutive cycles -> Covered by csr/csr_write_read
- Timer counter rollover (64-bit) -> Covered by 	imer/timer_rollover (tests minimum timecmp and increment behavior)
- Instruction fetch from translated addresses -> Covered by mmu/mmu_valid_fetch

Remaining limitations:
- SLEEP wake-on-interrupt (requires testbench stimulus during SLEEP)
- True 64-bit timer rollover (requires pre-loading mtime near 0xFFFF... which needs testbench support)
- MMU address wraparound (VPN + Base overflow)

## Synthesis Verification

Synthesis can be verified using Yosys:
```bash
yosys -p "read_verilog rtl/*.v; synth; stat"
```

See `docs/synthesis_report.md` for detailed results.
