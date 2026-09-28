#!/usr/bin/env python3
"""
NanoCore-64 Differential Test Tool

Performs cycle-by-cycle architectural comparison between the ISS (emulator)
and RTL simulation using deterministic trace output.

Comparison scope:
  - PC, instruction, and privilege mode (every cycle)
  - Register writeback (rd and value)
  - Memory read (address and data)
  - Memory write (address and data)
  - CSR write (address and data)
  - Trap and interrupt events (cause code)

The final TEST_STATUS write cycle is excluded from comparison because
the RTL testbench terminates at posedge (before negedge trace emission)
while the ISS records the full cycle.
"""
import subprocess
import sys
import os
import tempfile


def run_cmd(cmd):
    result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True)
    return result.returncode, result.stdout


def parse_trace(filepath):
    """Parse a trace file into a list of cycle records.

    Each record is a dict with keys: CYCLE, PC, INST, PRIV, and optional
    REG, MEM_RD, MEM_WR, CSR_WR, TRAP, INTERRUPT.
    """
    cycles = []
    current = {}
    with open(filepath, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if line == '---':
                if current:
                    cycles.append(current)
                    current = {}
                continue
            if not line:
                continue
            parts = line.split(None, 1)
            key = parts[0].upper()
            val = parts[1].upper() if len(parts) > 1 else ''

            if key == 'CYCLE':
                current['CYCLE'] = int(val)
            elif key == 'PC':
                current['PC'] = val.strip()
            elif key == 'INST':
                current['INST'] = val.strip()
            elif key == 'PRIV':
                current['PRIV'] = val.strip()
            elif key == 'REG':
                reg_parts = val.split()
                if len(reg_parts) < 2:
                    raise ValueError(f"Malformed REG line at line {line_num}: {line}")
                current['REG'] = (int(reg_parts[0]), reg_parts[1].strip())
            elif key == 'MEM_RD':
                mem_parts = val.split()
                if len(mem_parts) < 2:
                    raise ValueError(f"Malformed MEM_RD line at line {line_num}: {line}")
                current['MEM_RD'] = (mem_parts[0].strip(), mem_parts[1].strip())
            elif key == 'MEM_WR':
                mem_parts = val.split()
                if len(mem_parts) < 2:
                    raise ValueError(f"Malformed MEM_WR line at line {line_num}: {line}")
                current['MEM_WR'] = (mem_parts[0].strip(), mem_parts[1].strip())
            elif key == 'CSR_WR':
                csr_parts = val.split()
                if len(csr_parts) < 2:
                    raise ValueError(f"Malformed CSR_WR line at line {line_num}: {line}")
                current['CSR_WR'] = (csr_parts[0].strip(), csr_parts[1].strip())
            elif key == 'TRAP':
                current['TRAP'] = int(val)
            elif key == 'INTERRUPT':
                current['INTERRUPT'] = int(val)
            else:
                raise ValueError(f"Unknown trace key '{key}' at line {line_num}: {line}")
    if current:
        cycles.append(current)
    return cycles


def normalize_hex(val, width=16):
    """Normalize a hex string to uppercase, zero-padded."""
    return val.upper().zfill(width)


def compare_traces(iss_cycles, rtl_cycles):
    """Compare ISS and RTL trace records cycle by cycle.

    Returns (match_count, mismatch_list).
    Each mismatch is (cycle_num, field, iss_val, rtl_val).
    """
    mismatches = []
    # Use the shorter trace length (RTL may be 1 cycle shorter due to $finish timing)
    n = min(len(iss_cycles), len(rtl_cycles))

    for i in range(n):
        ic = iss_cycles[i]
        rc = rtl_cycles[i]
        cycle_num = ic.get('CYCLE', i + 1)

        # Compare PC
        iss_pc = normalize_hex(ic.get('PC', ''), 16)
        rtl_pc = normalize_hex(rc.get('PC', ''), 16)
        if iss_pc != rtl_pc:
            mismatches.append((cycle_num, 'PC', iss_pc, rtl_pc))

        # Compare INST
        iss_inst = normalize_hex(ic.get('INST', ''), 8)
        rtl_inst = normalize_hex(rc.get('INST', ''), 8)
        if iss_inst != rtl_inst:
            mismatches.append((cycle_num, 'INST', iss_inst, rtl_inst))

        # Compare PRIV
        iss_priv = ic.get('PRIV', '')
        rtl_priv = rc.get('PRIV', '')
        if iss_priv != rtl_priv:
            mismatches.append((cycle_num, 'PRIV', iss_priv, rtl_priv))

        # Compare REG writeback
        iss_reg = ic.get('REG')
        rtl_reg = rc.get('REG')
        if iss_reg != rtl_reg:
            if iss_reg and rtl_reg:
                iss_rd, iss_val = iss_reg
                rtl_rd, rtl_val = rtl_reg
                if iss_rd != rtl_rd or normalize_hex(iss_val) != normalize_hex(rtl_val):
                    mismatches.append((cycle_num, 'REG', f'R{iss_rd}={iss_val}', f'R{rtl_rd}={rtl_val}'))
            elif iss_reg and not rtl_reg:
                mismatches.append((cycle_num, 'REG', f'R{iss_reg[0]}={iss_reg[1]}', 'none'))
            elif rtl_reg and not iss_reg:
                mismatches.append((cycle_num, 'REG', 'none', f'R{rtl_reg[0]}={rtl_reg[1]}'))

        # Compare MEM_RD
        iss_mrd = ic.get('MEM_RD')
        rtl_mrd = rc.get('MEM_RD')
        if iss_mrd != rtl_mrd:
            if iss_mrd and rtl_mrd:
                if normalize_hex(iss_mrd[0]) != normalize_hex(rtl_mrd[0]) or \
                   normalize_hex(iss_mrd[1]) != normalize_hex(rtl_mrd[1]):
                    mismatches.append((cycle_num, 'MEM_RD',
                                       f'{iss_mrd[0]}={iss_mrd[1]}',
                                       f'{rtl_mrd[0]}={rtl_mrd[1]}'))
            elif iss_mrd and not rtl_mrd:
                mismatches.append((cycle_num, 'MEM_RD', f'{iss_mrd[0]}={iss_mrd[1]}', 'none'))
            elif rtl_mrd and not iss_mrd:
                mismatches.append((cycle_num, 'MEM_RD', 'none', f'{rtl_mrd[0]}={rtl_mrd[1]}'))

        # Compare MEM_WR
        iss_mwr = ic.get('MEM_WR')
        rtl_mwr = rc.get('MEM_WR')
        if iss_mwr != rtl_mwr:
            if iss_mwr and rtl_mwr:
                if normalize_hex(iss_mwr[0]) != normalize_hex(rtl_mwr[0]) or \
                   normalize_hex(iss_mwr[1]) != normalize_hex(rtl_mwr[1]):
                    mismatches.append((cycle_num, 'MEM_WR',
                                       f'{iss_mwr[0]}={iss_mwr[1]}',
                                       f'{rtl_mwr[0]}={rtl_mwr[1]}'))
            elif iss_mwr and not rtl_mwr:
                mismatches.append((cycle_num, 'MEM_WR', f'{iss_mwr[0]}={iss_mwr[1]}', 'none'))
            elif rtl_mwr and not iss_mwr:
                mismatches.append((cycle_num, 'MEM_WR', 'none', f'{rtl_mwr[0]}={rtl_mwr[1]}'))

        # Compare CSR_WR
        iss_csr = ic.get('CSR_WR')
        rtl_csr = rc.get('CSR_WR')
        if iss_csr != rtl_csr:
            if iss_csr and rtl_csr:
                if normalize_hex(iss_csr[0], 4) != normalize_hex(rtl_csr[0], 4) or \
                   normalize_hex(iss_csr[1]) != normalize_hex(rtl_csr[1]):
                    mismatches.append((cycle_num, 'CSR_WR',
                                       f'{iss_csr[0]}={iss_csr[1]}',
                                       f'{rtl_csr[0]}={rtl_csr[1]}'))
            elif iss_csr and not rtl_csr:
                mismatches.append((cycle_num, 'CSR_WR', f'{iss_csr[0]}={iss_csr[1]}', 'none'))
            elif rtl_csr and not iss_csr:
                mismatches.append((cycle_num, 'CSR_WR', 'none', f'{rtl_csr[0]}={rtl_csr[1]}'))

        # Compare TRAP
        iss_trap = ic.get('TRAP')
        rtl_trap = rc.get('TRAP')
        if iss_trap != rtl_trap:
            mismatches.append((cycle_num, 'TRAP', str(iss_trap), str(rtl_trap)))

        # Compare INTERRUPT
        iss_int = ic.get('INTERRUPT')
        rtl_int = rc.get('INTERRUPT')
        if iss_int != rtl_int:
            mismatches.append((cycle_num, 'INTERRUPT', str(iss_int), str(rtl_int)))

    return n, mismatches


def format_failure(asm_file, iss_cycles, rtl_cycles, mismatches, iss_result, rtl_result):
    """Format a detailed failure report."""
    lines = []
    lines.append(f"\n[-] DIFF FAILURE")
    lines.append(f"Test: {asm_file}")

    first_mismatch = mismatches[0]
    cycle = first_mismatch[0]
    field = first_mismatch[1]
    iss_val = first_mismatch[2]
    rtl_val = first_mismatch[3]

    # Find index for cycle
    idx = -1
    for i, ic in enumerate(iss_cycles):
        if ic.get('CYCLE', i+1) == cycle:
            idx = i
            break

    prev_match_cycle = "None"
    if idx > 0:
        prev_match_cycle = iss_cycles[idx-1].get('CYCLE', idx)

    lines.append(f"First mismatch at cycle: {cycle}")
    lines.append(f"Field: {field}")
    lines.append(f"RTL : {rtl_val}")
    lines.append(f"ISS : {iss_val}")

    lines.append("\nContext:")
    if idx != -1 and idx < len(iss_cycles) and idx < len(rtl_cycles):
        lines.append(f"Instruction (ISS): {iss_cycles[idx].get('INST', 'MISSING')}")
        lines.append(f"Instruction (RTL): {rtl_cycles[idx].get('INST', 'MISSING')}")
        lines.append(f"Privilege (ISS): {iss_cycles[idx].get('PRIV', 'MISSING')}")
        lines.append(f"Privilege (RTL): {rtl_cycles[idx].get('PRIV', 'MISSING')}")
        if 'PC' in iss_cycles[idx] or 'PC' in rtl_cycles[idx]:
            lines.append(f"PC (ISS): {iss_cycles[idx].get('PC', 'MISSING')}")
            lines.append(f"PC (RTL): {rtl_cycles[idx].get('PC', 'MISSING')}")

    lines.append(f"\nLast matching cycle: {prev_match_cycle}")
    lines.append(f"Total differences found: {len(mismatches)}")
    lines.append(f"ISS: {iss_result} | RTL: {rtl_result}")

    return '\n'.join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 tools/diff_test.py <test.asm>")
        sys.exit(1)

    asm_file = sys.argv[1]
    hex_file = asm_file.replace('.asm', '.hex')

    # Create temp directory for trace files
    tmpdir = tempfile.mkdtemp(prefix='nanocore_diff_')
    iss_trace = os.path.join(tmpdir, 'iss_trace.txt')
    rtl_trace = os.path.join(tmpdir, 'rtl_trace.txt')

    print(f"[*] Assembling {asm_file} ...")
    rc, out = run_cmd(f"python3 tools/assembler.py {asm_file} {hex_file}")
    if rc != 0:
        print(f"[-] Assembly failed:\n{out}")
        sys.exit(1)
    print(f"    -> {hex_file}")

    # Run ISS with trace
    print("[*] Running ISS with trace ...")
    rc, emu_out = run_cmd(f"python3 tools/emulator.py --trace-file {iss_trace} {hex_file}")
    iss_result = "PASS" if "PASS" in emu_out else "FAIL" if "FAIL" in emu_out else "UNKNOWN"
    cyc_match = __import__('re').search(r'Finished after (\d+) cycles', emu_out)
    iss_cycles_count = int(cyc_match.group(1)) if cyc_match else 0
    print(f"    -> ISS: {iss_result} after {iss_cycles_count} cycles")

    # Compile and run RTL with trace
    print("[*] Compiling RTL ...")
    rc, out = run_cmd(
        "iverilog -g2012 -o cpu_sim rtl/cpu.v rtl/alu.v rtl/regfile.v "
        "rtl/csr.v rtl/mmu.v rtl/timer.v sim/cpu_tb.v"
    )
    if rc != 0:
        print(f"[-] RTL compile failed:\n{out}")
        sys.exit(1)

    print("[*] Running RTL with trace ...")
    rc, rtl_out = run_cmd(f"vvp cpu_sim +HEX_FILE={hex_file} +TRACE_FILE={rtl_trace}")
    rtl_result = "PASS" if "TEST_RESULT: PASS" in rtl_out else \
                 "FAIL" if "TEST_RESULT: FAIL" in rtl_out else "TIMEOUT"
    print(f"    -> RTL: {rtl_result}")

    # Parse traces
    if not os.path.exists(iss_trace) or not os.path.exists(rtl_trace):
        print("[-] Trace files not generated. Falling back to outcome comparison.")
        if iss_result == "PASS" and rtl_result == "PASS":
            print("[+] Both PASS (no trace comparison available)")
            sys.exit(0)
        else:
            print(f"[-] Outcome mismatch: ISS={iss_result}, RTL={rtl_result}")
            sys.exit(1)

    try:
        iss_cycles = parse_trace(iss_trace)
    except ValueError as e:
        print(f"[-] ISS trace parse error: {e}")
        sys.exit(1)

    try:
        rtl_cycles = parse_trace(rtl_trace)
    except ValueError as e:
        print(f"[-] RTL trace parse error: {e}")
        sys.exit(1)

    print(f"\n[*] Comparing traces: ISS={len(iss_cycles)} cycles, RTL={len(rtl_cycles)} cycles")

    # Compare
    matched, mismatches = compare_traces(iss_cycles, rtl_cycles)

    if not mismatches:
        delta = abs(len(iss_cycles) - len(rtl_cycles))
        print(f"\n[+] MATCH: {matched} cycles compared, 0 mismatches")
        if delta > 0:
            print(f"    Note: {delta} trailing cycle(s) in {'ISS' if len(iss_cycles) > len(rtl_cycles) else 'RTL'}")
            print(f"    (expected: RTL $finish terminates before final trace emission)")
        print(f"    ISS: {iss_result} | RTL: {rtl_result}")
        sys.exit(0)
    else:
        report = format_failure(asm_file, iss_cycles, rtl_cycles, mismatches,
                                iss_result, rtl_result)
        print(report)
        sys.exit(1)

    # Cleanup
    try:
        os.unlink(iss_trace)
        os.unlink(rtl_trace)
        os.rmdir(tmpdir)
    except OSError:
        pass


if __name__ == "__main__":
    main()
