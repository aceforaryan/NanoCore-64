#!/usr/bin/env python3
"""
NanoCore-64 Instruction Set Simulator (ISS)

Cycle Model:
  Each call to step() represents one CPU clock cycle.
  Within each cycle, the following operations occur in order:

  1. mtime increments (mtime = mtime + 1)
     - This models the RTL timer.v sequential increment on posedge clk.
  2. Timer interrupt check
     - interrupt_req = GIE && (mtime >= TIMECMP)
     - If true: trap entry (EPC=PC, CAUSE=3, M-mode, GIE=0, PC=0)
     - This models the RTL combinational interrupt_req check against
       the just-updated registered mtime value.
  3. If halted (SLEEP): no instruction executes, step returns.
  4. Instruction fetch via MMU
     - Page fault check on instruction address.
  5. Decode and execute
     - Register reads, ALU, memory, CSR, control flow.
  6. PC update
     - next_pc is committed.

  This ordering matches the RTL single-cycle datapath where:
  - timer.v increments mtime on posedge clk
  - cpu.v combinational decode sees the new mtime via interrupt_req
  - if no interrupt, the instruction at current PC executes
  - PC register updates on the next posedge clk
"""
import sys

# TEST_STATUS codes (matching testbench MMIO at 0x20000000)
TEST_PASS = 0x00
TEST_ASSERT_FAIL = 0x01
TEST_EXCEPTION = 0x02
TEST_TIMEOUT = 0x03
TEST_UNKNOWN = 0x04

class NanoCore64Emulator:
    def __init__(self, trace=False, trace_file=None):
        self.trace = trace
        self.trace_file = trace_file  # File object for architectural trace output
        self.regs = [0] * 32
        self.inst_mem = [0] * 4096 # 16KB Instruction Memory
        self.data_mem = [0] * 4096 # 32KB Data Memory (using 64-bit words)
        
        # CSRs
        self.csrs = {
            0: 1, # STATUS (M-mode)
            1: 0, # EPC
            2: 0, # CAUSE
            3: 0, # MMU_PTB
            4: 0, # TVAL
            5: 0, # TIME
            6: 0xFFFFFFFFFFFFFFFF, # TIMECMP
        }
        self.priv_mode = 1 # 1: Machine, 0: User
        
        self.mtime = 0
        self.pc = 0
        self.halted = False
        self.cycle = 0
        self.test_status = None  # None = still running, int = finished
        
        # Per-cycle trace event state (reset each cycle)
        self._trace_events = {}

    def load_hex(self, filename):
        with open(filename, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('//'): continue
                if line.startswith('@'):
                    parts = line.split()
                    addr = int(parts[0][1:], 16)
                    val = int(parts[1], 16)
                    self.inst_mem[addr] = val
                else:
                    print("Unsupported hex format.")

    def sign_extend(self, val, bits):
        sign_bit = 1 << (bits - 1)
        return (val & (sign_bit - 1)) - (val & sign_bit)

    def write_reg(self, reg, val):
        if reg != 0:
            self.regs[reg] = val & 0xFFFFFFFFFFFFFFFF
            self._trace_events['reg_write'] = (reg, self.regs[reg])
            if self.trace and not self.trace_file:
                print(f"TRACE REG {reg:02d}={self.regs[reg]:016X}")

    def _take_trap(self, cause):
        """Hardware trap entry: save state, enter M-mode, disable interrupts."""
        self.csrs[1] = self.pc          # EPC <- PC
        self.csrs[2] = cause            # CAUSE <- cause code
        self.priv_mode = 1              # Enter M-mode
        self.csrs[0] = (self.csrs[0] & ~3) | 1  # STATUS[0]=1 (M-mode), STATUS[1]=0 (GIE off)
        self.pc = 0                     # PC <- trap vector
        if cause == 3:
            self._trace_events['interrupt'] = cause
        else:
            self._trace_events['trap'] = cause

    def check_page_fault(self, vpn, paddr):
        if self.csrs[3] == 0 or self.priv_mode != 0:
            return False
            
        if paddr == 0x10000000:
            return False # UART is exempt
        
        limit = (self.csrs[3] >> 32) & 0xFFFFFFFF
        if vpn >= limit:
            return True # Virtual Address Out of Bounds
            
        return False

    def _translate_addr(self, vaddr):
        """Translate virtual address through MMU. Returns (paddr, page_fault)."""
        vpn = (vaddr >> 12)
        if self.csrs[3] != 0 and self.priv_mode == 0:
            if vaddr == 0x10000000:
                paddr = vaddr
            else:
                base_ppn = self.csrs[3] & 0xFFFFFFFF
                paddr = ((vpn + base_ppn) << 12) | (vaddr & 0xFFF)
        else:
            paddr = vaddr
        fault = self.check_page_fault(vpn, paddr)
        return paddr, fault

    def read_mem(self, vaddr):
        paddr, fault = self._translate_addr(vaddr)
        if fault:
            return None # Indicate page fault
            
        word_addr = (paddr >> 3)
        if 0 <= word_addr < len(self.data_mem):
            val = self.data_mem[word_addr]
            self._trace_events['mem_read'] = (paddr, val)
            return val
        self._trace_events['mem_read'] = (paddr, 0)
        return 0

    def write_mem(self, vaddr, val):
        paddr, fault = self._translate_addr(vaddr)
        if fault:
            return False # Indicate page fault
            
        # Memory-Mapped UART
        if paddr == 0x10000000:
            print(chr(val & 0xFF), end='', flush=True)
            self._trace_events['mem_write'] = (paddr, val & 0xFF)
            return True

        # Memory-Mapped TEST_STATUS
        if paddr == 0x20000000:
            self.test_status = val & 0xFFFFFFFFFFFFFFFF
            self._trace_events['mem_write'] = (paddr, val & 0xFFFFFFFFFFFFFFFF)
            return True

        word_addr = (paddr >> 3)
        if 0 <= word_addr < len(self.data_mem):
            self.data_mem[word_addr] = val & 0xFFFFFFFFFFFFFFFF
            self._trace_events['mem_write'] = (paddr, val & 0xFFFFFFFFFFFFFFFF)
            if self.trace and not self.trace_file:
                print(f"TRACE MEM {paddr:016X}={val:016X}")
        return True

    def _emit_trace(self, pc, inst, priv):
        """Write one architectural trace record for the current cycle.
        
        Trace format (one line per field, grouped by cycle):
          CYCLE <n>
          PC <hex>
          INST <hex>
          PRIV <M|U>
          REG <rd> <hex>        (if register writeback occurred)
          MEM_RD <addr> <hex>   (if memory read occurred)
          MEM_WR <addr> <hex>   (if memory write occurred)
          CSR_WR <addr> <hex>   (if CSR write occurred)
          TRAP <cause>          (if synchronous trap occurred)
          INTERRUPT <cause>     (if asynchronous interrupt occurred)
          ---                   (cycle separator)
        """
        if not self.trace_file:
            return
        f = self.trace_file
        f.write(f"CYCLE {self.cycle}\n")
        f.write(f"PC {pc:016X}\n")
        f.write(f"INST {inst:08X}\n")
        f.write(f"PRIV {'M' if priv else 'U'}\n")
        ev = self._trace_events
        if 'reg_write' in ev:
            rd, val = ev['reg_write']
            f.write(f"REG {rd} {val:016X}\n")
        if 'mem_read' in ev:
            addr, val = ev['mem_read']
            f.write(f"MEM_RD {addr:016X} {val:016X}\n")
        if 'mem_write' in ev:
            addr, val = ev['mem_write']
            f.write(f"MEM_WR {addr:016X} {val:016X}\n")
        if 'csr_write' in ev:
            csr_addr, val = ev['csr_write']
            f.write(f"CSR_WR {csr_addr:04X} {val:016X}\n")
        if 'trap' in ev:
            f.write(f"TRAP {ev['trap']}\n")
        if 'interrupt' in ev:
            f.write(f"INTERRUPT {ev['interrupt']}\n")
        f.write("---\n")

    def step(self):
        """Execute one CPU clock cycle. Returns True if CPU is still active.
        
        Timer model:
          RTL uses nonblocking assign: mtime <= mtime + 1 at posedge clk.
          The instruction and interrupt check (combinational) see the OLD mtime
          because NBAs update after the Active region. The increment becomes
          visible on the next cycle.
          
          ISS models this as: check interrupt with current mtime, execute
          instruction with current mtime, then increment mtime at end of step.
        """
        self.cycle += 1
        self._trace_events = {}  # Reset per-cycle trace events
        cycle_pc = self.pc      # Capture PC at start of cycle
        cycle_priv = self.priv_mode

        # Step 1: Check timer interrupt using CURRENT mtime (pre-increment)
        # Matches RTL: combinational interrupt_req = STATUS[1] & (mtime >= TIMECMP)
        # where mtime is the registered value from the PREVIOUS cycle.
        if (self.csrs[0] & 2) and (self.mtime >= self.csrs[6]):
            self._take_trap(3)  # Timer Interrupt
            self.halted = False
            self._emit_trace(cycle_pc, 0, cycle_priv)
            # Increment mtime at end of cycle (RTL NBA)
            self.mtime += 1
            self.csrs[5] = self.mtime
            return True

        # Step 2: If halted (SLEEP), no instruction executes
        if self.halted:
            self._emit_trace(cycle_pc, 0, cycle_priv)
            # Increment mtime at end of cycle (RTL NBA)
            self.mtime += 1
            self.csrs[5] = self.mtime
            return False

        if self.trace and not self.trace_file:
            print(f"TRACE PC={self.pc:016X}")

        # Step 3: Instruction fetch with MMU translation
        inst_paddr, inst_fault = self._translate_addr(self.pc)
        if inst_fault:
            self._take_trap(2)  # Page Fault
            self._emit_trace(cycle_pc, 0, cycle_priv)
            self.mtime += 1
            self.csrs[5] = self.mtime
            return True

        word_pc = inst_paddr >> 2
        inst = self.inst_mem[word_pc] if word_pc < len(self.inst_mem) else 0
        cycle_inst = inst
        
        # Decode
        opcode = inst & 0x3F
        rd  = (inst >> 6) & 0x1F
        rs1 = (inst >> 11) & 0x1F
        rs2 = (inst >> 16) & 0x1F
        imm16 = (inst >> 16) & 0xFFFF
        imm21 = (inst >> 11) & 0x1FFFFF
        
        imm16_ext = self.sign_extend(imm16, 16)
        imm21_ext = self.sign_extend(imm21, 21)
        
        # Step 5: Execute
        next_pc = self.pc + 4

        if opcode == 0x00: pass  # NOP
        elif opcode in (0x01, 0x21): # ADD / ADDI
            b = imm16_ext if opcode == 0x21 else self.regs[rs2]
            self.write_reg(rd, self.regs[rs1] + b)
        elif opcode == 0x02: # SUB
            self.write_reg(rd, self.regs[rs1] - self.regs[rs2])
        elif opcode in (0x03, 0x23): # AND / ANDI
            b = imm16_ext if opcode == 0x23 else self.regs[rs2]
            self.write_reg(rd, self.regs[rs1] & b)
        elif opcode in (0x04, 0x24): # OR / ORI
            b = imm16_ext if opcode == 0x24 else self.regs[rs2]
            self.write_reg(rd, self.regs[rs1] | b)
        elif opcode in (0x05, 0x25): # XOR / XORI
            b = imm16_ext if opcode == 0x25 else self.regs[rs2]
            self.write_reg(rd, self.regs[rs1] ^ b)
        elif opcode in (0x06, 0x26): # SHL / SHLI
            b = (imm16_ext & 0x3F) if opcode == 0x26 else (self.regs[rs2] & 0x3F)
            self.write_reg(rd, self.regs[rs1] << b)
        elif opcode in (0x07, 0x27): # SHR / SHRI
            b = (imm16_ext & 0x3F) if opcode == 0x27 else (self.regs[rs2] & 0x3F)
            self.write_reg(rd, self.regs[rs1] >> b)
        elif opcode == 0x08: # LD
            val = self.read_mem(self.regs[rs1] + imm16_ext)
            if val is None:
                self._take_trap(2)  # Page Fault
                self._emit_trace(cycle_pc, cycle_inst, cycle_priv)
                self.mtime += 1
                self.csrs[5] = self.mtime
                return True
            self.write_reg(rd, val)
        elif opcode == 0x09: # ST
            if not self.write_mem(self.regs[rs1] + imm16_ext, self.regs[rd]):
                self._take_trap(2)  # Page Fault
                self._emit_trace(cycle_pc, cycle_inst, cycle_priv)
                self.mtime += 1
                self.csrs[5] = self.mtime
                return True
        elif opcode == 0x0A: # BEQ
            if self.regs[rd] == self.regs[rs1]: next_pc = self.pc + 4 + (imm16_ext * 4)
        elif opcode == 0x0B: # BNE
            if self.regs[rd] != self.regs[rs1]: next_pc = self.pc + 4 + (imm16_ext * 4)
        elif opcode == 0x0C: # JAL
            self.write_reg(rd, self.pc + 4)
            next_pc = self.pc + 4 + (imm21_ext * 4)
        elif opcode == 0x0D: # JALR
            self.write_reg(rd, self.pc + 4)
            next_pc = self.regs[rs1] + imm16_ext
        elif opcode == 0x0E: # CSRR (M-Mode only per ISA)
            if self.priv_mode == 0:
                self._take_trap(4)  # Privilege Violation
                self._emit_trace(cycle_pc, cycle_inst, cycle_priv)
                self.mtime += 1
                self.csrs[5] = self.mtime
                return True
            else:
                self.write_reg(rd, self.csrs.get(imm16, 0))
        elif opcode == 0x0F: # CSRW
            if self.priv_mode == 0:
                self._take_trap(4)  # Privilege Violation
                self._emit_trace(cycle_pc, cycle_inst, cycle_priv)
                self.mtime += 1
                self.csrs[5] = self.mtime
                return True
            else:
                self.csrs[imm16] = self.regs[rs1]
                self._trace_events['csr_write'] = (imm16, self.regs[rs1])
                if imm16 == 0:
                    self.priv_mode = self.regs[rs1] & 1
        elif opcode == 0x10: # SYSCALL
            self._take_trap(1)  # Syscall
            self._emit_trace(cycle_pc, cycle_inst, cycle_priv)
            self.mtime += 1
            self.csrs[5] = self.mtime
            return True
        elif opcode == 0x11: # RET
            # Restore privilege from STATUS[0], jump to EPC
            # Software must configure STATUS via CSRW before RET
            self.priv_mode = self.csrs[0] & 1
            next_pc = self.csrs[1]
        elif opcode == 0x3F: # SLEEP
            self.halted = True
            next_pc = self.pc
        else:
            print(f"Unknown opcode at PC={self.pc}: {opcode:02X}")
            self.halted = True

        # Step 6: Update PC
        self.pc = next_pc & 0xFFFFFFFFFFFFFFFF
        self._emit_trace(cycle_pc, cycle_inst, cycle_priv)
        # Increment mtime at end of cycle (RTL NBA)
        self.mtime += 1
        self.csrs[5] = self.mtime
        return not self.halted

    def dump(self):
        for i in range(32):
            print(f"R{i:<2}: 0x{self.regs[i]:016X}", end="  ")
            if (i + 1) % 2 == 0: print()

if __name__ == "__main__":
    import sys
    trace = "--trace" in sys.argv
    if trace: sys.argv.remove("--trace")
    trace_file_path = None
    if "--trace-file" in sys.argv:
        idx = sys.argv.index("--trace-file")
        trace_file_path = sys.argv[idx + 1]
        sys.argv.pop(idx)
        sys.argv.pop(idx)
    if len(sys.argv) != 2:
        print("Usage: python3 emulator.py [--trace] [--trace-file <path>] <program.hex>")
        sys.exit(1)
    tf = open(trace_file_path, 'w') if trace_file_path else None
    emu = NanoCore64Emulator(trace=trace, trace_file=tf)
    emu.load_hex(sys.argv[1])
    print("--- Starting Execution ---")
    max_cycles = 50000
    while emu.cycle < max_cycles:
        emu.step()
        # Check for test completion via TEST_STATUS MMIO
        if emu.test_status is not None:
            if emu.test_status == TEST_PASS:
                print(f"\n--- PASS after {emu.cycle} cycles ---")
            else:
                print(f"\n--- FAIL (status={emu.test_status}) after {emu.cycle} cycles ---")
            break
        # If halted and interrupts are disabled, we can safely exit early
        if emu.halted and not (emu.csrs[0] & 2):
            break
    else:
        print(f"\n--- Timeout after {max_cycles} cycles ---")
    print(f"--- Finished after {emu.cycle} cycles ---")
    emu.dump()
    if tf:
        tf.close()
