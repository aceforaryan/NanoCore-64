#!/usr/bin/env python3
"""
NanoCore-64 Seeded Randomized Differential Test Generator

Generates short, random but valid instruction sequences, assembles them,
runs both ISS and RTL simulation, and compares architectural traces.

Each seed produces a deterministic program. Failing seeds can be recorded
and reproduced for debugging.

Usage:
    python3 tools/random_test.py [--seeds N] [--seed S]
"""
import random
import subprocess
import sys
import os
import tempfile
import shutil


# Instruction generators — each returns an assembly line
def gen_addi(rng):
    rd = rng.randint(1, 15)
    rs1 = rng.randint(0, 15)
    imm = rng.randint(-32768, 32767)
    return f"ADDI R{rd}, R{rs1}, {imm}"

def gen_add(rng):
    rd = rng.randint(1, 15)
    rs1 = rng.randint(0, 15)
    rs2 = rng.randint(0, 15)
    return f"ADD R{rd}, R{rs1}, R{rs2}"

def gen_sub(rng):
    rd = rng.randint(1, 15)
    rs1 = rng.randint(0, 15)
    rs2 = rng.randint(0, 15)
    return f"SUB R{rd}, R{rs1}, R{rs2}"

def gen_and(rng):
    rd = rng.randint(1, 15)
    rs1 = rng.randint(0, 15)
    rs2 = rng.randint(0, 15)
    return f"AND R{rd}, R{rs1}, R{rs2}"

def gen_or(rng):
    rd = rng.randint(1, 15)
    rs1 = rng.randint(0, 15)
    rs2 = rng.randint(0, 15)
    return f"OR R{rd}, R{rs1}, R{rs2}"

def gen_xor(rng):
    rd = rng.randint(1, 15)
    rs1 = rng.randint(0, 15)
    rs2 = rng.randint(0, 15)
    return f"XOR R{rd}, R{rs1}, R{rs2}"

def gen_shl(rng):
    rd = rng.randint(1, 15)
    rs1 = rng.randint(0, 15)
    rs2 = rng.randint(0, 15)
    return f"SHL R{rd}, R{rs1}, R{rs2}"

def gen_shr(rng):
    rd = rng.randint(1, 15)
    rs1 = rng.randint(0, 15)
    rs2 = rng.randint(0, 15)
    return f"SHR R{rd}, R{rs1}, R{rs2}"

def gen_shli(rng):
    rd = rng.randint(1, 15)
    rs1 = rng.randint(0, 15)
    shamt = rng.randint(0, 63)
    return f"SHLI R{rd}, R{rs1}, {shamt}"

def gen_shri(rng):
    rd = rng.randint(1, 15)
    rs1 = rng.randint(0, 15)
    shamt = rng.randint(0, 63)
    return f"SHRI R{rd}, R{rs1}, {shamt}"

def gen_andi(rng):
    rd = rng.randint(1, 15)
    rs1 = rng.randint(0, 15)
    imm = rng.randint(-32768, 32767)
    return f"ANDI R{rd}, R{rs1}, {imm}"

def gen_ori(rng):
    rd = rng.randint(1, 15)
    rs1 = rng.randint(0, 15)
    imm = rng.randint(-32768, 32767)
    return f"ORI R{rd}, R{rs1}, {imm}"

def gen_xori(rng):
    rd = rng.randint(1, 15)
    rs1 = rng.randint(0, 15)
    imm = rng.randint(-32768, 32767)
    return f"XORI R{rd}, R{rs1}, {imm}"

def gen_nop(rng):
    return "NOP"

def gen_st_ld(rng):
    """Generate a matched ST/LD pair to a safe data memory address."""
    rd = rng.randint(1, 15)
    # Use R0 as base, offset is a safe aligned data address
    # Data memory starts at word 0. Use offsets 256-1024 (byte addr)
    offset = rng.choice([256, 512, 768, 1024, 1280, 1536]) 
    return f"ST R{rd}, R0, {offset}\n    LD R{rd}, R0, {offset}"


# Weighted instruction generators (bias toward ALU, some memory)
GENERATORS = [
    (gen_addi, 20),
    (gen_add, 10),
    (gen_sub, 10),
    (gen_and, 5),
    (gen_or, 5),
    (gen_xor, 5),
    (gen_shl, 5),
    (gen_shr, 5),
    (gen_shli, 5),
    (gen_shri, 5),
    (gen_andi, 5),
    (gen_ori, 5),
    (gen_xori, 5),
    (gen_nop, 5),
    (gen_st_ld, 10),
]


PASSFAIL_INLINE = """
test_pass:
    ADDI R1, R0, 0x2000
    SHLI R1, R1, 16
    ADDI R2, R0, 0
    ST R2, R1, 0
    SLEEP

test_fail:
    ADDI R1, R0, 0x2000
    SHLI R1, R1, 16
    ADDI R2, R0, 1
    ST R2, R1, 0
    SLEEP
"""

def generate_program(seed, num_instructions=30):
    """Generate a random but valid NanoCore-64 program."""
    rng = random.Random(seed)
    
    # Build weighted generator list
    weighted = []
    for gen, weight in GENERATORS:
        weighted.extend([gen] * weight)
    
    lines = [f"; Random test program (seed={seed})"]
    
    for _ in range(num_instructions):
        gen = rng.choice(weighted)
        lines.append(f"    {gen(rng)}")
    
    # Terminate with PASS
    lines.append("")
    lines.append("    JAL R0, test_pass")
    lines.append("")
    lines.append(PASSFAIL_INLINE)
    
    return '\n'.join(lines) + '\n'


def run_cmd(cmd):
    result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True)
    return result.returncode, result.stdout


def run_seed(seed, tmpdir, verbose=False):
    """Run one seed through assembly -> ISS -> RTL -> diff. Returns (passed, msg)."""
    program = generate_program(seed)
    
    asm_file = os.path.join(tmpdir, f'rand_{seed}.asm')
    hex_file = os.path.join(tmpdir, f'rand_{seed}.hex')
    iss_trace = os.path.join(tmpdir, f'iss_{seed}.txt')
    rtl_trace = os.path.join(tmpdir, f'rtl_{seed}.txt')
    
    with open(asm_file, 'w') as f:
        f.write(program)
    
    # Assemble
    rc, out = run_cmd(f"python3 tools/assembler.py {asm_file} {hex_file}")
    if rc != 0:
        return False, f"Assembly failed: {out}"
    
    # Run ISS
    rc, iss_out = run_cmd(f"python3 tools/emulator.py --trace-file {iss_trace} {hex_file}")
    if "PASS" not in iss_out and "FAIL" not in iss_out:
        return False, f"ISS did not complete: {iss_out[:200]}"
    
    # Run RTL
    rc, rtl_out = run_cmd(f"vvp cpu_sim +HEX_FILE={hex_file} +TRACE_FILE={rtl_trace}")
    if "TEST_RESULT: PASS" not in rtl_out:
        return False, f"RTL did not PASS: {rtl_out[:200]}"
    
    # Compare traces
    from diff_test import parse_trace, compare_traces
    
    if not os.path.exists(iss_trace) or not os.path.exists(rtl_trace):
        return False, "Trace files not generated"
    
    iss_cycles = parse_trace(iss_trace)
    rtl_cycles = parse_trace(rtl_trace)
    
    matched, mismatches = compare_traces(iss_cycles, rtl_cycles)
    
    if mismatches:
        first = mismatches[0]
        return False, f"Mismatch at cycle {first[0]}: {first[1]} ISS={first[2]} RTL={first[3]}"
    
    return True, f"MATCH ({matched} cycles)"


def main():
    import argparse
    parser = argparse.ArgumentParser(description="NanoCore-64 Randomized Differential Testing")
    parser.add_argument('--seeds', type=int, default=20, help='Number of random seeds to test')
    parser.add_argument('--seed', type=int, default=None, help='Run a specific seed only')
    parser.add_argument('--verbose', action='store_true', help='Verbose output')
    args = parser.parse_args()
    
    # Ensure RTL is compiled
    if not os.path.exists('cpu_sim'):
        print("[*] Compiling RTL...")
        rc, out = run_cmd(
            "iverilog -g2012 -o cpu_sim rtl/cpu.v rtl/alu.v rtl/regfile.v "
            "rtl/csr.v rtl/mmu.v rtl/timer.v sim/cpu_tb.v"
        )
        if rc != 0:
            print(f"RTL compile failed:\n{out}")
            sys.exit(1)
    
    tmpdir = tempfile.mkdtemp(prefix='nanocore_rand_')
    
    # Add tools/ to path for imports
    sys.path.insert(0, 'tools')
    
    if args.seed is not None:
        seeds = [args.seed]
    else:
        seeds = list(range(1, args.seeds + 1))
    
    passed = 0
    failed = 0
    failures = []
    
    print(f"[*] Running {len(seeds)} randomized differential tests")
    print(f"    Temp dir: {tmpdir}")
    print()
    
    for seed in seeds:
        ok, msg = run_seed(seed, tmpdir, args.verbose)
        status = "PASS" if ok else "FAIL"
        print(f"  seed={seed:>5d}  {status}  {msg}")
        if ok:
            passed += 1
        else:
            failed += 1
            failures.append((seed, msg))
    
    print()
    print(f"Results: {passed}/{len(seeds)} passed, {failed} failed")
    
    if failures:
        print("\nFailing seeds:")
        for seed, msg in failures:
            print(f"  seed={seed}: {msg}")
        print(f"\nReproduce: python3 tools/random_test.py --seed <N>")
    
    # Cleanup
    shutil.rmtree(tmpdir, ignore_errors=True)
    
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
