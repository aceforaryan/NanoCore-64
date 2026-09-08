# NanoCore-64 Architecture

## Design Philosophy

NanoCore-64 is a single-cycle, area-optimized 64-bit processor. It trades throughput for simplicity: no pipeline, no branch prediction, no speculative execution, no caches. Complex operations like multiply/divide are handled in software.

Priority order: **Correctness → Security/Isolation → Area → Simplicity → Timing → Performance**

## Top-Level Module: `cpu.v`

The CPU module integrates all submodules and implements combinational decode/control logic with a sequential PC register.

### Ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| clk | in | 1 | System clock |
| rst | in | 1 | Active-high asynchronous reset |
| imem_addr | out | 64 | Instruction memory address (physical) |
| imem_data | in | 32 | Instruction word |
| dmem_addr | out | 64 | Data memory address (physical) |
| dmem_wdata | out | 64 | Data memory write data |
| dmem_rdata | in | 64 | Data memory read data |
| dmem_we | out | 1 | Data memory write enable |
| dmem_re | out | 1 | Data memory read enable |
| sleep_mode | out | 1 | CPU halted (SLEEP instruction) |

### Instruction Flow

```
PC → imem_mmu → imem_addr → instruction fetch
                                    ↓
                              instruction decode
                              (opcode, rd, rs1, rs2, imm)
                                    ↓
                          ┌─────────┴──────────┐
                          ↓                    ↓
                    register read         immediate gen
                    (rf_rd1, rf_rd2)      (imm16_sext, imm21_sext)
                          ↓                    ↓
                          └─────────┬──────────┘
                                    ↓
                              ALU / Branch
                                    ↓
                          ┌────┬────┴────┬────┐
                          ↓    ↓         ↓    ↓
                        ALU  Memory    CSR  Control
                       result access  access (trap/ret)
                          ↓    ↓         ↓    ↓
                          └────┴────┬────┴────┘
                                    ↓
                              write-back mux
                              (rf_wd_mux → rd)
                                    ↓
                              next PC calculation
```

### ALU Operand Selection

- R-type instructions (opcode 0x01–0x07): `alu_in_b = rf_rd2` (register)
- I-type instructions (opcode 0x21–0x27, LD, ST): `alu_in_b = imm16_sext` (immediate)

### Branch Register Operands

For BEQ/BNE/ST, the `rs2` read port is remapped to read from `rd` instead of `rs2`:
```
rs2_sel = (opcode == BEQ || opcode == BNE || opcode == ST) ? rd : rs2
```
This allows the I-type encoding `[Imm16][Rs1][Rd][Opcode]` to compare `Rd` vs `Rs1`.

## Register File: `regfile.v`

- 32 × 64-bit registers
- R0 hardwired to zero (reads always return 0, writes ignored)
- Asynchronous read, synchronous write
- Active-high asynchronous reset (all registers zeroed)
- Debug ports: `r1_out`, `r2_out` expose R1 and R2

## ALU: `alu.v`

| Control | Operation |
|---------|-----------|
| 000 | ADD |
| 001 | SUB |
| 010 | AND |
| 011 | OR |
| 100 | XOR |
| 101 | SHL (shift left by b[5:0]) |
| 110 | SHR (logical shift right by b[5:0]) |
| 111 | (default: 0) |

- 64-bit operations throughout
- Shift amounts masked to 6 bits (0–63)
- Zero flag output: `result == 0`
- No signed shift right (arithmetic shift not implemented)

## CSR Subsystem: `csr.v`

### Registers and Reset Values

| CSR | Address | Reset Value | Notes |
|-----|---------|-------------|-------|
| STATUS | 0x0000 | 0x01 (M-mode) | Bit 0: privilege, Bit 1: GIE |
| EPC | 0x0001 | 0x00 | Exception PC |
| CAUSE | 0x0002 | 0x00 | Trap cause |
| MMU_PTB | 0x0003 | 0x00 | Page table base |
| TVAL | 0x0004 | 0x00 | Trap value |
| TIME | 0x0005 | (reflects mtime) | Read-only |
| TIMECMP | 0x0006 | 0xFFFF...F | Timer disabled |

### Priority Chain (sequential update)

```
reset > trap_req > eret_req > csr_we
```

### Trap Entry

Hardware atomically: saves EPC, sets CAUSE, enters M-mode, disables interrupts.

### Exception Return (eret_req)

Restores `priv_mode` from `STATUS[0]`. Does not modify STATUS.

### Interrupt Generation

```
interrupt_req_out = STATUS[1] & timer_interrupt_in
```

## MMU: `mmu.v`

Two instances: one for instruction fetch, one for data access.

### Control Logic

```
vmem_enabled = (mmu_ptb != 0) && (priv_mode == 0)
```

- If disabled: `physical_addr = virtual_addr` (identity mapping)
- If enabled: `physical_addr = ((VPN + base_ppn) << 12) | offset`

### Bounds Check

```
page_fault = mem_req && vmem_enabled && (VPN >= VPN_limit) && !is_uart
```

UART address `0x10000000` bypasses both translation and bounds checking.

## Timer: `timer.v`

- Free-running 64-bit counter (`mtime`), increments every clock cycle
- Interrupt when `mtime >= timecmp`
- Disabling: write `0xFFFFFFFFFFFFFFFF` to TIMECMP
- No prescaler — counter runs at system clock frequency

## Privilege Model

- **Machine Mode (M):** Full access to all CSRs, memory, and instructions. Identity-mapped MMU.
- **User Mode (U):** No CSR access (CSRR/CSRW trap with Cause=4). MMU active if PTB≠0.

### Mode Transitions

| From | To | Mechanism |
|------|----|-----------|
| M → U | Software writes STATUS[0]=0 via CSRW, then RET reads it |
| U → M | Hardware trap (SYSCALL, page fault, privilege violation, timer interrupt) |

### Reset State

After reset: PC=0, priv_mode=1 (M-mode), STATUS=1, all GPRs=0, TIMECMP=max.

## Clocking and Reset

- Single clock domain
- Asynchronous active-high reset on all sequential elements
- Combinational logic settles within one clock period (single-cycle assumption)
