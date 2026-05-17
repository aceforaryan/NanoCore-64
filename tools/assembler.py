#!/usr/bin/env python3
import sys
import re

OPCODES = {
    "NOP":   0x00,
    "ADD":   0x01,
    "SUB":   0x02,
    "AND":   0x03,
    "OR":    0x04,
    "XOR":   0x05,
    "SHL":   0x06,
    "SHR":   0x07,
    "LD":    0x08,
    "ST":    0x09,
    "BEQ":   0x0A,
    "BNE":   0x0B,
    "JAL":   0x0C,
    "JALR":  0x0D,
    "CSRR":  0x0E,
    "CSRW":  0x0F,
    "SYSCALL": 0x10,
    "RET":   0x11,
    "ADDI":  0x21,
    "ANDI":  0x23,
    "ORI":   0x24,
    "XORI":  0x25,
    "SHLI":  0x26,
    "SHRI":  0x27,
    "SLEEP": 0x3F,
}

def parse_register(reg_str):
    if reg_str.upper() == "PC":
        return 32 # Special value but not a GPR
    if not reg_str.upper().startswith("R"):
        raise ValueError(f"Invalid register syntax: {reg_str}")
    num = int(reg_str[1:])
    if not (0 <= num <= 31):
        raise ValueError(f"Register out of bounds: R{num}")
    return num

def parse_immediate(imm_str):
    if imm_str.upper().startswith("0X"):
        return int(imm_str, 16)
    elif imm_str.upper().startswith("0B"):
        return int(imm_str, 2)
    else:
        return int(imm_str)

def assemble(input_file, output_file):
    with open(input_file, 'r') as f:
        lines = f.readlines()

    # Pass 1: Resolve Labels
    labels = {}
    current_addr = 0
    instructions = []
    
    for line in lines:
        line = line.split(';')[0].strip() # Remove comments
        if not line:
            continue
        
        # Check for label
        if line.endswith(':'):
            label = line[:-1]
            labels[label] = current_addr
            continue
            
        if ':' in line:
            label_part, inst_part = line.split(':', 1)
            labels[label_part.strip()] = current_addr
            line = inst_part.strip()
            if not line:
                continue

        instructions.append((current_addr, line))
        current_addr += 4 # 32-bit instructions increment by 4 bytes (but we might write out word addresses)

    # Convert to word addresses for output
    hex_output = []
    
    for addr, line in instructions:
        parts = [p.strip(',') for p in line.split()]
        mnem = parts[0].upper()
        
        if mnem not in OPCODES:
            raise ValueError(f"Unknown opcode: {mnem}")
        
        opcode = OPCODES[mnem]
        inst_bin = opcode
        
        if mnem in ["NOP", "SLEEP", "SYSCALL", "RET"]:
            pass # No operands needed
            
        elif mnem in ["ADD", "SUB", "AND", "OR", "XOR", "SHL", "SHR"]:
            # R-Type: OP Rd, Rs1, Rs2
            rd = parse_register(parts[1])
            rs1 = parse_register(parts[2])
            rs2 = parse_register(parts[3])
            inst_bin |= (rd << 6) | (rs1 << 11) | (rs2 << 16)
            
        elif mnem in ["ADDI", "ANDI", "ORI", "XORI", "SHLI", "SHRI", "LD", "ST", "JALR"]:
            # I-Type: OP Rd, Rs1, Imm
            rd = parse_register(parts[1])
            rs1 = parse_register(parts[2])
            imm = parse_immediate(parts[3]) & 0xFFFF
            inst_bin |= (rd << 6) | (rs1 << 11) | (imm << 16)
            
        elif mnem in ["BEQ", "BNE"]:
            # I-Type Branch: OP Rd, Rs1, Target
            rd = parse_register(parts[1])
            rs1 = parse_register(parts[2])
            target = parts[3]
            
            if target in labels:
                offset = (labels[target] - (addr + 4)) // 4
            else:
                offset = parse_immediate(target)
            imm = offset & 0xFFFF
            inst_bin |= (rd << 6) | (rs1 << 11) | (imm << 16)
            
        elif mnem in ["CSRR", "CSRW"]:
            # I-Type: CSRR Rd, CSR_Addr  || CSRW CSR_Addr, Rs1
            if mnem == "CSRR":
                rd = parse_register(parts[1])
                imm = parse_immediate(parts[2]) & 0xFFFF
                inst_bin |= (rd << 6) | (0 << 11) | (imm << 16)
            else:
                imm = parse_immediate(parts[1]) & 0xFFFF
                rs1 = parse_register(parts[2])
                inst_bin |= (0 << 6) | (rs1 << 11) | (imm << 16)
                
        elif mnem == "JAL":
            # J-Type: OP Rd, Target
            rd = parse_register(parts[1])
            target = parts[2]
            
            if target in labels:
                offset = (labels[target] - (addr + 4)) // 4
            else:
                offset = parse_immediate(target)
            imm = offset & 0x1FFFFF
            inst_bin |= (rd << 6) | (imm << 11)

        # Write to hex (Verilog $readmemh with 32-bit chunks)
        hex_output.append(f"@{addr//4:08X} {inst_bin:08X}")

    with open(output_file, 'w') as f:
        f.write('\n'.join(hex_output) + '\n')
        
    print(f"Assembly completed. Output written to {output_file}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 assembler.py <input.asm> <output.hex>")
        sys.exit(1)
    assemble(sys.argv[1], sys.argv[2])
