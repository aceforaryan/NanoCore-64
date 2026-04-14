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
        }
        self.priv_mode = 1 # 1: Machine, 0: User
        
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

    def read_mem(self, vaddr):
        # Simplified Memory
        paddr = vaddr
        if self.csrs[3] != 0:
            vpn = (vaddr >> 12)
            paddr = ((vpn + self.csrs[3]) << 12) | (vaddr & 0xFFF)
        word_addr = (paddr >> 3)
        if 0 <= word_addr < len(self.data_mem):
            return self.data_mem[word_addr]
        return 0

    def write_mem(self, vaddr, val):
        paddr = vaddr
        if self.csrs[3] != 0:
            vpn = (vaddr >> 12)
            paddr = ((vpn + self.csrs[3]) << 12) | (vaddr & 0xFFF)
        word_addr = (paddr >> 3)
        if 0 <= word_addr < len(self.data_mem):
            self.data_mem[word_addr] = val & 0xFFFFFFFFFFFFFFFF

    def step(self):
        if self.halted: return False

        word_pc = self.pc >> 2
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
            self.write_reg(rd, self.read_mem(self.regs[rs1] + imm16_ext))
        elif opcode == 0x09: # ST
            self.write_mem(self.regs[rs1] + imm16_ext, self.regs[rd])
        elif opcode == 0x0A: # BEQ
            if self.regs[rd] == self.regs[rs1]: next_pc = self.pc + (imm16_ext * 4)
        elif opcode == 0x0B: # BNE
            if self.regs[rd] != self.regs[rs1]: next_pc = self.pc + (imm16_ext * 4)
        elif opcode == 0x0C: # JAL
            self.write_reg(rd, self.pc + 4)
            next_pc = self.pc + (imm21_ext * 4)
        elif opcode == 0x0D: # JALR
            self.write_reg(rd, self.pc + 4)
            next_pc = self.regs[rs1] + imm16_ext
        elif opcode == 0x0E: # CSRR
            self.write_reg(rd, self.csrs.get(imm16, 0))
        elif opcode == 0x0F: # CSRW
            self.csrs[imm16] = self.regs[rs1]
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
    while not emu.halted and cycles < 10000:
        emu.step()
        cycles += 1
    print(f"--- Halted after {cycles} cycles ---")
    emu.dump()
