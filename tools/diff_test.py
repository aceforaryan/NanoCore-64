#!/usr/bin/env python3
import subprocess
import sys
import os

def run_cmd(cmd, cwd="."):
    result = subprocess.run(cmd, cwd=cwd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return result.stdout

def extract_traces(output):
    traces = []
    for line in output.split('\n'):
        line = line.strip()
        if line.startswith('TRACE '):
            traces.append(line)
    return traces

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 tools/diff_test.py <test.asm>")
        sys.exit(1)
        
    asm_file = sys.argv[1]
    hex_file = asm_file.replace('.asm', '.hex')
    
    print(f"[*] Assembling {asm_file} to {hex_file}...")
    run_cmd(f"python3 tools/assembler.py {asm_file} {hex_file}")
    
    print("[*] Running Emulator...")
    emu_out = run_cmd(f"python3 tools/emulator.py --trace {hex_file}")
    emu_traces = extract_traces(emu_out)
    
    print("[*] Compiling RTL...")
    rtl_compile_cmd = "iverilog -o sim/cpu_sim rtl/cpu.v rtl/alu.v rtl/regfile.v rtl/csr.v rtl/mmu.v rtl/timer.v sim/cpu_tb.v"
    run_cmd(rtl_compile_cmd)
    
    print(f"[*] Running RTL Simulation with {hex_file}...")
    rtl_out = run_cmd(f"vvp sim/cpu_sim +HEX_FILE={hex_file}")
    rtl_traces = extract_traces(rtl_out)
    
    print(f"[*] Comparing traces (Emulator: {len(emu_traces)} lines vs RTL: {len(rtl_traces)} lines)")
    
    max_len = max(len(emu_traces), len(rtl_traces))
    mismatch = False
    
    for i in range(max_len):
        emu_line = emu_traces[i] if i < len(emu_traces) else "<EOF>"
        rtl_line = rtl_traces[i] if i < len(rtl_traces) else "<EOF>"
        
        if emu_line != rtl_line:
            print(f"\n[!] MISMATCH at Step {i}:")
            print(f"    Emulator : {emu_line}")
            print(f"    RTL      : {rtl_line}")
            mismatch = True
            break
            
    if not mismatch:
        print("\n[+] SUCCESS! Differential Test Passed. Both implementations match perfectly.")
    else:
        print("\n[-] FAIL: Implementations diverged.")
        sys.exit(1)

if __name__ == "__main__":
    main()
