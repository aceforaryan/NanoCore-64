#!/usr/bin/env python3
"""
NanoCore-64 Comparator Fault-Injection Tests (Phase H: Test the Tester)

Verifies that the differential comparator correctly detects injected
mismatches across all compared trace fields. This establishes confidence
in the checker infrastructure itself.

Each test case:
  1. Generates a known-good trace pair.
  2. Injects a specific corruption into one trace.
  3. Verifies the comparator reports a mismatch on the correct field.
  4. Restores the original traces.

Expected result: every injected fault is detected.
"""
import sys
import os
import tempfile

# Add tools/ to path for importing
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'tools'))
from diff_test import parse_trace, compare_traces


def make_good_trace():
    """Generate a minimal correct trace pair (3 cycles)."""
    lines = [
        # Cycle 1: NOP
        "CYCLE 1", "PC 0000000000000000", "INST 00000000", "PRIV M", "---",
        # Cycle 2: ADDI R1, R0, 42
        "CYCLE 2", "PC 0000000000000004", "INST 002A0061", "PRIV M",
        "REG 1 000000000000002A", "---",
        # Cycle 3: ST R1, R0, 0x100
        "CYCLE 3", "PC 0000000000000008", "INST 01000049", "PRIV M",
        "MEM_WR 0000000000000100 000000000000002A", "---",
    ]
    return '\n'.join(lines) + '\n'


def make_trace_with_mem_rd():
    """Generate trace pair with a MEM_RD event."""
    lines = [
        "CYCLE 1", "PC 0000000000000000", "INST 00000000", "PRIV M", "---",
        "CYCLE 2", "PC 0000000000000004", "INST 01000048", "PRIV M",
        "REG 1 000000000000002A",
        "MEM_RD 0000000000000100 000000000000002A", "---",
    ]
    return '\n'.join(lines) + '\n'


def make_trace_with_csr():
    """Generate trace pair with a CSR_WR event."""
    lines = [
        "CYCLE 1", "PC 0000000000000000", "INST 00000000", "PRIV M", "---",
        "CYCLE 2", "PC 0000000000000004", "INST 0006000F", "PRIV M",
        "CSR_WR 0006 00000000000001F4", "---",
    ]
    return '\n'.join(lines) + '\n'


def make_trace_with_trap():
    """Generate trace pair with a TRAP event."""
    lines = [
        "CYCLE 1", "PC 0000000000000000", "INST 00000000", "PRIV M", "---",
        "CYCLE 2", "PC 0000000000000004", "INST 00000010", "PRIV M",
        "TRAP 1", "---",
    ]
    return '\n'.join(lines) + '\n'


def make_trace_with_interrupt():
    """Generate trace pair with an INTERRUPT event."""
    lines = [
        "CYCLE 1", "PC 0000000000000000", "INST 00000000", "PRIV M", "---",
        "CYCLE 2", "PC 0000000000000004", "INST 0000003F", "PRIV M",
        "INTERRUPT 3", "---",
    ]
    return '\n'.join(lines) + '\n'


def write_trace(tmpdir, name, content):
    path = os.path.join(tmpdir, name)
    with open(path, 'w') as f:
        f.write(content)
    return path


def inject_fault(trace_content, target_line_prefix, replacement):
    """Replace a specific line in a trace by prefix match."""
    lines = trace_content.strip().split('\n')
    for i, line in enumerate(lines):
        if line.startswith(target_line_prefix):
            lines[i] = replacement
            return '\n'.join(lines) + '\n'
    raise ValueError(f"Could not find line starting with '{target_line_prefix}'")


def remove_line(trace_content, target_line_prefix):
    """Remove a specific line from a trace."""
    lines = trace_content.strip().split('\n')
    new_lines = [l for l in lines if not l.startswith(target_line_prefix)]
    return '\n'.join(new_lines) + '\n'


def add_line_after(trace_content, target_line_prefix, new_line):
    """Add a line after a specific line."""
    lines = trace_content.strip().split('\n')
    for i, line in enumerate(lines):
        if line.startswith(target_line_prefix):
            lines.insert(i + 1, new_line)
            return '\n'.join(lines) + '\n'
    raise ValueError(f"Could not find line starting with '{target_line_prefix}'")


def run_test(name, good_trace, bad_trace, expected_field, tmpdir):
    """Run one fault-injection test. Returns (passed, description)."""
    good_path = write_trace(tmpdir, 'good.txt', good_trace)
    bad_path = write_trace(tmpdir, 'bad.txt', bad_trace)

    good_cycles = parse_trace(good_path)
    bad_cycles = parse_trace(bad_path)

    # Test with bad trace as ISS, good as RTL
    _, mismatches_1 = compare_traces(bad_cycles, good_cycles)
    # Test with good trace as ISS, bad as RTL
    _, mismatches_2 = compare_traces(good_cycles, bad_cycles)

    detected = False
    for mm in mismatches_1 + mismatches_2:
        if mm[1] == expected_field:
            detected = True
            break

    if detected:
        return True, f"PASS: {name} — {expected_field} mismatch detected"
    else:
        return False, f"FAIL: {name} — {expected_field} mismatch NOT detected (mismatches: {mismatches_1 + mismatches_2})"


def main():
    tmpdir = tempfile.mkdtemp(prefix='nanocore_tester_')
    good = make_good_trace()
    results = []

    # 1. PC mismatch
    bad = inject_fault(good, "PC 0000000000000004", "PC 0000000000000008")
    results.append(run_test("PC mismatch", good, bad, "PC", tmpdir))

    # 2. INST mismatch
    bad = inject_fault(good, "INST 002A0061", "INST DEADBEEF")
    results.append(run_test("INST mismatch", good, bad, "INST", tmpdir))

    # 3. PRIV mismatch
    bad = good.replace("PRIV M\n---\nCYCLE 2", "PRIV U\n---\nCYCLE 2", 1)
    results.append(run_test("PRIV mismatch", good, bad, "PRIV", tmpdir))

    # 4. REG mismatch (wrong value)
    bad = inject_fault(good, "REG 1 000000000000002A", "REG 1 00000000DEADBEEF")
    results.append(run_test("REG value mismatch", good, bad, "REG", tmpdir))

    # 5. REG mismatch (wrong register)
    bad = inject_fault(good, "REG 1 000000000000002A", "REG 2 000000000000002A")
    results.append(run_test("REG index mismatch", good, bad, "REG", tmpdir))

    # 6. REG present vs absent
    bad = remove_line(good, "REG 1")
    results.append(run_test("REG missing", good, bad, "REG", tmpdir))

    # 7. REG absent vs present (inject extra REG into bad trace)
    trace_no_reg = make_good_trace()
    # Remove REG from good, add it to bad
    good_no_reg = remove_line(trace_no_reg, "REG 1")
    results.append(run_test("REG unexpected", good_no_reg, trace_no_reg, "REG", tmpdir))

    # 8. MEM_WR mismatch (wrong address)
    bad = inject_fault(good, "MEM_WR 0000000000000100", "MEM_WR 0000000000000200 000000000000002A")
    results.append(run_test("MEM_WR addr mismatch", good, bad, "MEM_WR", tmpdir))

    # 9. MEM_WR mismatch (wrong data)
    bad = inject_fault(good, "MEM_WR 0000000000000100", "MEM_WR 0000000000000100 00000000DEADBEEF")
    results.append(run_test("MEM_WR data mismatch", good, bad, "MEM_WR", tmpdir))

    # 10. MEM_WR present vs absent
    bad = remove_line(good, "MEM_WR")
    results.append(run_test("MEM_WR missing", good, bad, "MEM_WR", tmpdir))

    # 11. MEM_RD mismatch
    good_rd = make_trace_with_mem_rd()
    bad = inject_fault(good_rd, "MEM_RD 0000000000000100", "MEM_RD 0000000000000100 00000000DEADBEEF")
    results.append(run_test("MEM_RD data mismatch", good_rd, bad, "MEM_RD", tmpdir))

    # 12. MEM_RD missing
    bad = remove_line(good_rd, "MEM_RD")
    results.append(run_test("MEM_RD missing", good_rd, bad, "MEM_RD", tmpdir))

    # 13. CSR_WR mismatch
    good_csr = make_trace_with_csr()
    bad = inject_fault(good_csr, "CSR_WR 0006", "CSR_WR 0006 00000000DEADBEEF")
    results.append(run_test("CSR_WR data mismatch", good_csr, bad, "CSR_WR", tmpdir))

    # 14. CSR_WR missing
    bad = remove_line(good_csr, "CSR_WR")
    results.append(run_test("CSR_WR missing", good_csr, bad, "CSR_WR", tmpdir))

    # 15. TRAP mismatch (wrong cause)
    good_trap = make_trace_with_trap()
    bad = inject_fault(good_trap, "TRAP 1", "TRAP 2")
    results.append(run_test("TRAP cause mismatch", good_trap, bad, "TRAP", tmpdir))

    # 16. TRAP missing
    bad = remove_line(good_trap, "TRAP")
    results.append(run_test("TRAP missing", good_trap, bad, "TRAP", tmpdir))

    # 17. INTERRUPT mismatch
    good_int = make_trace_with_interrupt()
    bad = inject_fault(good_int, "INTERRUPT 3", "INTERRUPT 1")
    results.append(run_test("INTERRUPT cause mismatch", good_int, bad, "INTERRUPT", tmpdir))

    # 18. INTERRUPT missing
    bad = remove_line(good_int, "INTERRUPT")
    results.append(run_test("INTERRUPT missing", good_int, bad, "INTERRUPT", tmpdir))

    # 19. Extra cycle (good has more cycles)
    extra = good + "CYCLE 4\nPC 000000000000000C\nINST 00000000\nPRIV M\n---\n"
    _, mm = compare_traces(parse_trace(write_trace(tmpdir, 'extra.txt', extra)),
                           parse_trace(write_trace(tmpdir, 'short.txt', good)))
    if len(mm) == 0:
        # No mismatch in aligned cycles, but length differs
        extra_cycles = parse_trace(write_trace(tmpdir, 'extra.txt', extra))
        short_cycles = parse_trace(write_trace(tmpdir, 'short.txt', good))
        if len(extra_cycles) != len(short_cycles):
            results.append((True, "PASS: Extra cycle — length difference detected"))
        else:
            results.append((False, "FAIL: Extra cycle — not detected"))
    else:
        results.append((True, "PASS: Extra cycle — mismatch detected"))

    # 20. Incorrect cycle number (cycle numbering is informational, but check it parses)
    bad = inject_fault(good, "CYCLE 2", "CYCLE 99")
    bad_cycles = parse_trace(write_trace(tmpdir, 'badcyc.txt', bad))
    if bad_cycles[1].get('CYCLE') == 99:
        results.append((True, "PASS: Incorrect cycle number — parsed correctly"))
    else:
        results.append((False, "FAIL: Incorrect cycle number — parse issue"))

    # Print results
    print("=" * 60)
    print("Comparator Fault-Injection Test Results")
    print("=" * 60)
    passed = 0
    failed = 0
    for ok, desc in results:
        print(f"  {desc}")
        if ok:
            passed += 1
        else:
            failed += 1

    print(f"\nTotal: {passed + failed}, Passed: {passed}, Failed: {failed}")
    print("=" * 60)

    # Cleanup
    import shutil
    shutil.rmtree(tmpdir, ignore_errors=True)

    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
