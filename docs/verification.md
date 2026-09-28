# NanoCore-64 Verification

## Simulation Environment

- **Simulator:** Icarus Verilog (`iverilog` + `vvp`)
- **Testbench:** `sim/cpu_tb.v`
- **Assembler:** `tools/assembler.py` (Python 3)
- **Emulator:** `tools/emulator.py` (Python 3 ISS)
- **Regression:** `tools/regression.py`
- **Differential Test:** `tools/diff_test.py`
- **Comparator Validation:** `tools/test_comparator.py`
- **Randomized Testing:** `tools/random_test.py`

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
| `alu/arith_boundary` | INT64_MAX, INT64_MIN, wraparound, sign-extension | Signed boundary values |
| `alu/logic_shifts` | AND, OR, XOR, SHL, SHR, ANDI, ORI, XORI, SHLI, SHRI | Logic and shift operations |
| `alu/shift_boundary` | Shift by 0, 1, 31, 32, 63 | Shift amount boundaries |
| `alu/r0_protection` | Writes to R0 via ADDI, ADD, LD, JAL | R0 hardwired-zero enforcement |
| `branch/branches` | BEQ taken/not-taken, BNE taken/not-taken, backward branch | Control flow |
| `branch/branch_boundary` | Zero displacement, forward, backward, loop | Branch boundary conditions |
| `branch/jalr_test` | JALR with computed, offset, negative targets | Indirect jumps |
| `memory/memory` | Aligned LD/ST, offset access | Load/store |
| `memory/mmio_uart` | UART MMIO write, data memory isolation | MMIO |
| `csr/csr` | CSR read/write, SYSCALL trap + return | CSR and trap entry |
| `csr/csr_write_read` | Write-then-read for all CSRs | CSR read-after-write |
| `csr/csr_time_read` | TIME CSR increments across reads | Timer counter visibility |
| `exception/privilege_test` | User-mode CSRW → privilege violation trap | Privilege enforcement |
| `exception/traps_test` | SYSCALL → trap handler → RET → User mode | Full trap round-trip |
| `exception/back_to_back_traps` | Two sequential SYSCALLs with RET between | Sequential trap handling |
| `exception/ret_to_user` | M→U mode transition, user arithmetic, SYSCALL return | Full privilege round-trip |
| `mmu/mmu_test` | MMU enabled with invalid PTB → page fault | Instruction page fault |
| `mmu/mmu_ptb_test` | PTB write/read, identity mapping verification | Address translation |
| `mmu/mmu_valid_fetch` | User-mode instruction fetch with valid MMU mapping | Translated execution |
| `mmu/mmu_fault_boundary` | VPN == limit triggers fault (>= check) | MMU boundary condition |
| `timer/timer_test` | Timer interrupt generation and handling | Timer subsystem |
| `timer/timer_rollover` | Minimum timecmp, mtime increment verification | Timer edge case |
| `timer/timer_exact_compare` | Very tight TIMECMP margin (mtime+5) | Timer compare boundary |
| `timer/timer_disabled` | Timer condition met but GIE=0 | Interrupt masking |

### Test Structure

Each test file includes `passfail.inc` at the **end** (not the beginning) to ensure test code starts at PC=0. Tests that use traps include a trap dispatch sequence at PC=0:

```asm
    CSRR R31, 2         ; Read CAUSE
    BNE R31, R0, trap_handler
    JAL R0, boot         ; Normal boot if CAUSE == 0
```

## Running Tests

### Full Regression (RTL only)
```bash
make test
```

### Differential Regression (ISS vs RTL)
```bash
make diff
```

### Randomized Differential Testing
```bash
make fuzz
```

### Comparator Fault-Injection Tests
```bash
make test-comparator
```

### Single Test
```bash
python3 tools/assembler.py tests/alu/arithmetic.asm tests/alu/arithmetic.hex
iverilog -o cpu_sim rtl/cpu.v rtl/alu.v rtl/regfile.v rtl/csr.v rtl/mmu.v rtl/timer.v sim/cpu_tb.v
vvp cpu_sim +HEX_FILE=tests/alu/arithmetic.hex
```

### Differential Test (single)
```bash
python3 tools/diff_test.py tests/alu/arithmetic.asm
```

Results are written to `reports/latest/` with per-test logs and a summary.

## Architectural Trace Contract

Both RTL and ISS emit per-cycle trace records with the following schema:

| Field | Semantics | When Emitted |
|-------|-----------|-------------|
| `CYCLE <n>` | Sequential cycle number | Every cycle |
| `PC <hex16>` | Program counter at start of cycle | Every cycle |
| `INST <hex8>` | Instruction word at PC | Every cycle |
| `PRIV <M\|U>` | Privilege mode at start of cycle | Every cycle |
| `REG <rd> <hex16>` | Register writeback (rd ≠ 0) | If register write occurs |
| `MEM_RD <addr> <hex16>` | Data memory read | If load occurs |
| `MEM_WR <addr> <hex16>` | Data memory write | If store occurs |
| `CSR_WR <addr> <hex16>` | CSR write (M-mode only) | If CSR write occurs |
| `TRAP <cause>` | Synchronous trap | If trap occurs |
| `INTERRUPT <cause>` | Asynchronous interrupt | If interrupt accepted |
| `---` | Cycle separator | Every cycle |

### Cycle Semantics

- A trace record for cycle N represents the architectural state transition during that cycle.
- PC and PRIV are sampled at the **start** of the cycle (before the instruction executes).
- REG, MEM, CSR events reflect the operation that **executed** during the cycle.
- TRAP/INTERRUPT events reflect the trap that was **taken** during the cycle.

### SLEEP Representation

During SLEEP cycles, the CPU is architecturally stalled. Both RTL and ISS emit the SLEEP instruction word (`0x0000003F`) at the halted PC. This accurately reflects the single-cycle, non-clock-gated implementation where SLEEP holds PC constant.

### Termination Convention

Tests terminate via a TEST_STATUS MMIO store. The RTL testbench calls `$finish` at `posedge clk` (inside the memory write block), which occurs before the `negedge clk` trace emission for that final cycle. Consequently:
- The ISS trace contains one additional final cycle (the TEST_STATUS store).
- The RTL trace is exactly 1 cycle shorter.
- All overlapping aligned cycles match.

This is an intentional simulation-termination artifact, not an architectural mismatch.

### Timer Semantics

Both RTL and ISS evaluate timer interrupts based on the `mtime` value from the **previous** clock edge:
- RTL: `timer.v` uses nonblocking assignment (`mtime <= mtime + 1`), so the combinational `interrupt_req` sees the registered (old) `mtime`.
- ISS: Checks interrupt with current `mtime`, executes instruction, then increments `mtime` at end of step.

## Differential Verification

The comparator (`tools/diff_test.py`) performs strict field-by-field comparison:

**Compared fields:** PC, INST, PRIV, REG, MEM_RD, MEM_WR, CSR_WR, TRAP, INTERRUPT

**Mismatch detection:** Any field difference at any aligned cycle produces a failure with detailed diagnostics including cycle number, field name, ISS value, RTL value, and surrounding context.

**Malformed trace detection:** Unknown trace keys and malformed field values cause parse errors.

**Termination convention:** Only the documented 1-cycle trailing difference is tolerated. No other normalization is applied.

### Comparator Validation (Phase H)

The comparator is validated by 20 fault-injection tests (`tools/test_comparator.py`) that verify detection of:
- PC, INST, PRIV mismatches
- REG value/index/presence mismatches
- MEM_RD and MEM_WR address/data/presence mismatches
- CSR_WR data/presence mismatches
- TRAP and INTERRUPT cause/presence mismatches
- Extra cycles and cycle number parsing

All 20 injected faults are detected.

## Randomized Testing

The seeded test generator (`tools/random_test.py`) produces deterministic random instruction sequences:
- ALU operations (ADD, SUB, AND, OR, XOR, SHL, SHR and immediate variants)
- Memory operations (ST/LD pairs to safe addresses)
- NOP instructions
- Each program terminates with `JAL R0, test_pass`

Seeds are reproducible: `python3 tools/random_test.py --seed <N>`

## Known Emulator/RTL Differences

| Aspect | RTL | Emulator |
|--------|-----|----------|
| Undefined opcodes | NOP (silent) | Halts with error message |
| Instruction memory | 2048 × 32-bit (testbench) | 4096 × 32-bit |
| Data memory | 2048 × 64-bit (testbench) | 4096 × 64-bit |

## Remaining Verification Gaps

- True 64-bit timer rollover (requires pre-loading mtime near 0xFFFF... which needs testbench modification)
- MMU address wraparound (VPN + Base PPN overflow past 52 bits)
- Sub-word memory access (not architecturally supported)

## Failure Debugging Workflow

```
test fails
    ↓
capture exact mismatch (cycle, field, ISS value, RTL value)
    ↓
identify first divergence
    ↓
rerun with VCD: vvp cpu_sim +HEX_FILE=<hex> +DUMP_VCD=1
    ↓
inspect waveform: gtkwave cpu_tb.vcd
    ↓
identify RTL transition
    ↓
fix root cause
    ↓
add regression test
```

## Synthesis Verification

Synthesis can be verified using Yosys:
```bash
make synth
```

See `docs/synthesis_report.md` for detailed results.
