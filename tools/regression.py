#!/usr/bin/env python3
import os
import sys
import subprocess
import glob
import json
import time
import shutil
from datetime import datetime

class ArtifactManager:
    def __init__(self, base_dir="reports"):
        self.base_dir = base_dir
        self.latest_dir = os.path.join(self.base_dir, "latest")
        self.archive_dir = os.path.join(self.base_dir, "archive")
        self.logs_dir = os.path.join(self.latest_dir, "logs")
        
    def setup_directories(self):
        # Create directories if they don't exist
        os.makedirs(self.latest_dir, exist_ok=True)
        os.makedirs(self.archive_dir, exist_ok=True)
        # Clear out latest/logs
        if os.path.exists(self.logs_dir):
            shutil.rmtree(self.logs_dir)
        os.makedirs(self.logs_dir, exist_ok=True)

    def archive_run(self):
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M")
        dest_dir = os.path.join(self.archive_dir, timestamp)
        shutil.copytree(self.latest_dir, dest_dir)
        return dest_dir

    def store_log(self, test_name, log_content):
        log_path = os.path.join(self.logs_dir, f"{test_name}.log")
        with open(log_path, "w") as f:
            f.write(log_content)
        return log_path


class Assembler:
    def __init__(self, assembler_path="tools/assembler.py"):
        self.assembler_path = assembler_path

    def assemble(self, asm_file):
        hex_file = asm_file.replace(".asm", ".hex")
        cmd = [sys.executable, self.assembler_path, asm_file, hex_file]
        try:
            subprocess.run(cmd, check=True, capture_output=True, text=True)
            return hex_file
        except subprocess.CalledProcessError as e:
            print(f"Error assembling {asm_file}:\n{e.stderr}")
            return None


class Simulator:
    def __init__(self):
        self.sim_executable = "cpu_sim"
        
    def compile_rtl(self):
        print("Compiling RTL...")
        # iverilog -o cpu_sim rtl/*.v sim/cpu_tb.v
        rtl_files = glob.glob("rtl/*.v")
        cmd = ["iverilog", "-o", self.sim_executable] + rtl_files + ["sim/cpu_tb.v"]
        try:
            subprocess.run(cmd, check=True, capture_output=True, text=True)
            print("RTL compiled successfully.")
            return True
        except subprocess.CalledProcessError as e:
            print("RTL Compilation Failed:")
            print(e.stderr)
            return False

    def run_test(self, hex_file, generate_vcd=False):
        cmd = ["vvp", self.sim_executable, f"+HEX_FILE={hex_file}"]
        if generate_vcd:
            cmd.append("+DUMP_VCD=1")
            
        start_time = time.time()
        try:
            res = subprocess.run(cmd, capture_output=True, text=True)
            duration = time.time() - start_time
            return res.stdout, duration
        except Exception as e:
            return str(e), time.time() - start_time


class Reporter:
    def __init__(self, artifact_manager):
        self.am = artifact_manager
        self.results = {}
        self.categories = {}
        self.total_time = 0.0

    def record_result(self, category, test_name, status, log_content, duration):
        self.results[test_name] = status
        if category not in self.categories:
            self.categories[category] = {'total': 0, 'passed': 0}
            
        self.categories[category]['total'] += 1
        if status == "PASS":
            self.categories[category]['passed'] += 1
            
        self.am.store_log(test_name, log_content)
        self.total_time += duration

    def generate_reports(self):
        # JSON
        json_path = os.path.join(self.am.latest_dir, "results.json")
        with open(json_path, "w") as f:
            json.dump(self.results, f, indent=2)

        # Summary TXT
        total_tests = len(self.results)
        passed_tests = sum(1 for s in self.results.values() if s == "PASS")
        failed_tests = sum(1 for s in self.results.values() if s in ["FAIL", "EXCEPTION", "ASSEMBLY_ERROR"])
        timeout_tests = sum(1 for s in self.results.values() if s == "TIMEOUT")

        lines = [
            "====================================",
            "NanoCore Regression Summary",
            "====================================",
            "",
            f"Total Tests      : {total_tests}",
            f"Passed           : {passed_tests}",
            f"Failed           : {failed_tests}",
            f"Timeout          : {timeout_tests}",
            ""
        ]

        for cat, data in self.categories.items():
            cat_name = cat.capitalize()
            status_str = "PASS" if data['passed'] == data['total'] else "FAIL"
            lines.append(f"{cat_name:<16} {status_str} ({data['passed']}/{data['total']})")

        lines.extend([
            "",
            f"Execution Time   : {self.total_time:.2f} s",
            "===================================="
        ])

        summary_text = "\n".join(lines)
        print("\n" + summary_text)
        
        txt_path = os.path.join(self.am.latest_dir, "summary.txt")
        with open(txt_path, "w") as f:
            f.write(summary_text)


class RegressionRunner:
    def __init__(self):
        self.am = ArtifactManager()
        self.assembler = Assembler()
        self.simulator = Simulator()
        self.reporter = Reporter(self.am)

    def parse_status(self, stdout):
        if "TEST_RESULT: PASS" in stdout:
            return "PASS"
        elif "TEST_RESULT: TIMEOUT" in stdout:
            return "TIMEOUT"
        elif "TEST_RESULT: FAIL" in stdout:
            if "Status Code         : 02" in stdout:
                return "EXCEPTION"
            return "FAIL"
        else:
            return "UNKNOWN"

    def run(self):
        self.am.setup_directories()
        
        if not self.simulator.compile_rtl():
            sys.exit(1)

        # Find tests in categories
        test_files = glob.glob("tests/*/*.asm")
        # Filter out common folder just in case
        test_files = [f for f in test_files if "common" not in f]
        
        if not test_files:
            print("No tests found.")
            sys.exit(0)

        for asm_file in sorted(test_files):
            # Parse category from path: tests/<category>/<test_name>.asm
            parts = asm_file.split(os.sep)
            category = parts[1]
            test_name = parts[2].replace(".asm", "")
            
            print(f"Running {category}/{test_name}...", end=" ", flush=True)

            hex_file = self.assembler.assemble(asm_file)
            if not hex_file:
                print("ASSEMBLY FAILED")
                self.reporter.record_result(category, test_name, "ASSEMBLY_ERROR", "Assembly failed.", 0)
                continue

            # Run without VCD
            stdout, duration = self.simulator.run_test(hex_file, generate_vcd=False)
            status = self.parse_status(stdout)
            
            if status != "PASS":
                # Re-run with VCD
                print(f"FAIL ({status}). Re-running with VCD...", end=" ")
                stdout_vcd, duration_vcd = self.simulator.run_test(hex_file, generate_vcd=True)
                stdout = stdout_vcd
                duration += duration_vcd
                # If there's a cpu_tb.vcd, move it to logs dir
                if os.path.exists("cpu_tb.vcd"):
                    dest_vcd = os.path.join(self.am.logs_dir, f"{test_name}.vcd")
                    shutil.move("cpu_tb.vcd", dest_vcd)

            print(status)
            self.reporter.record_result(category, test_name, status, stdout, duration)

        self.reporter.generate_reports()
        self.am.archive_run()

if __name__ == "__main__":
    runner = RegressionRunner()
    runner.run()
