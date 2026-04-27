#!/usr/bin/env python3
import sys

class NanoCore64Emulator:
    def __init__(self):
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

    def check_page_fault(self, paddr):
        return self.csrs[3] != 0 and self.priv_mode == 0 and paddr < 0x10000

    def read_mem(self, vaddr):
        # Simplified Memory
        paddr = vaddr
        if self.csrs[3] != 0 and self.priv_mode == 0:
            vpn = (vaddr >> 12)
            paddr = ((vpn + self.csrs[3]) << 12) | (vaddr & 0xFFF)
        if self.check_page_fault(paddr):
            return None # Indicate page fault
        word_addr = (paddr >> 3)
        if 0 <= word_addr < len(self.data_mem):
            return self.data_mem[word_addr]
        return 0

    def write_mem(self, vaddr, val):
        paddr = vaddr
        if self.csrs[3] != 0 and self.priv_mode == 0:
            vpn = (vaddr >> 12)
            paddr = ((vpn + self.csrs[3]) << 12) | (vaddr & 0xFFF)
        if self.check_page_fault(paddr):
            return False # Indicate page fault
        word_addr = (paddr >> 3)
        if 0 <= word_addr < len(self.data_mem):
            self.data_mem[word_addr] = val & 0xFFFFFFFFFFFFFFFF
        return True

    def step(self):
        self.mtime += 1
        self.csrs[5] = self.mtime

        if (self.csrs[0] & 2) and (self.mtime >= self.csrs[6]):
            self.csrs[1] = self.pc
            self.csrs[2] = 3 # Timer Interrupt
            self.priv_mode = 1
            self.csrs[0] = self.csrs[0] & ~2 # Disable interrupts
            self.pc = 0
            self.halted = False
            return True

        if self.halted: return False

        # Instruction fetch
        inst_paddr = self.pc
        if self.csrs[3] != 0 and self.priv_mode == 0:
            vpn = (self.pc >> 12)
            inst_paddr = ((vpn + self.csrs[3]) << 12) | (self.pc & 0xFFF)
            
        if self.check_page_fault(inst_paddr):
            self.csrs[1] = self.pc
            self.csrs[2] = 2 # Page Fault
            self.priv_mode = 1
            self.pc = 0
            return True

        word_pc = inst_paddr >> 2
        inst = self.inst_mem[word_pc] if word_pc < len(self.inst_mem) else 0
        
        opcode = inst & 0x3F
        rd  = (inst >> 6) & 0x1F
        rs1 = (inst >> 11) & 0x1F
        rs2 = (inst >> 16) & 0x1F
        imm16 = (inst >> 16) & 0xFFFF
        imm21 = (inst >> 11) & 0x1FFFFF
        
        imm16_ext = self.sign_extend(imm16, 16)
        imm21_ext = self.sign_extend(imm21, 21)
        
        next_pc = self.pc + 4

        if opcode == 0x00: pass
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
                self.csrs[1] = self.pc
                self.csrs[2] = 2 # Page Fault
                self.priv_mode = 1
                self.pc = 0
                return True
            self.write_reg(rd, val)
        elif opcode == 0x09: # ST
            if not self.write_mem(self.regs[rs1] + imm16_ext, self.regs[rd]):
                self.csrs[1] = self.pc
                self.csrs[2] = 2 # Page Fault
                self.priv_mode = 1
                self.pc = 0
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
        elif opcode == 0x0E: # CSRR
            self.write_reg(rd, self.csrs.get(imm16, 0))
        elif opcode == 0x0F: # CSRW
            self.csrs[imm16] = self.regs[rs1]
            if imm16 == 0:
                self.priv_mode = self.regs[rs1] & 1
        elif opcode == 0x10: # SYSCALL
            self.csrs[1] = self.pc
            self.csrs[2] = 1 # Syscall cause
            self.priv_mode = 1
            next_pc = 0
        elif opcode == 0x11: # RET
            self.priv_mode = self.csrs[0] & 1
            next_pc = self.csrs[1]
        elif opcode == 0x3F: # SLEEP
            self.halted = True
            next_pc = self.pc
        else:
            print(f"Unknown opcode at PC={self.pc}: {opcode:02X}")
            self.halted = True

        self.pc = next_pc & 0xFFFFFFFFFFFFFFFF
        return not self.halted

    def dump(self):
        for i in range(32):
            print(f"R{i:<2}: 0x{self.regs[i]:016X}", end="  ")
            if (i + 1) % 2 == 0: print()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 emulator.py <program.hex>")
        sys.exit(1)
    emu = NanoCore64Emulator()
    emu.load_hex(sys.argv[1])
    print("--- Starting Execution ---")
    cycles = 0
    while cycles < 10000:
        emu.step()
        cycles += 1
        # If halted and interrupts are disabled natively, we can safely exit early
        if emu.halted and not (emu.csrs[0] & 2):
            break
    print(f"--- Finished after {cycles} cycles ---")
    emu.dump()
