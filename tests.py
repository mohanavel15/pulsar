import os
import subprocess
import glob

TEST_DIR = "riscv-tests-isa-ima"
EMULATOR = "zig-out/bin/mini_rv32_ima_zig"

def main():
    test_files = [f for f in glob.glob(f"{TEST_DIR}/*") if f.endswith('.bin')]
    print(f"Found {len(test_files)} tests in the test directory.\n")
    
    total = len(test_files)
    passed = 0
    failed = 0

    for file in sorted(test_files):
        test_name = os.path.basename(file)[0:-4]

        try:
            result = subprocess.run(
                [EMULATOR, file],
                capture_output=True,
                text=True,
                timeout=2 
            )
            
            if result.returncode == 0:
                passed += 1
            else:
                print(f"[FAIL] {test_name} - STDERR: {result.stderr}", end="")
                failed += 1
                
        except subprocess.TimeoutExpired:
            print(f"[HANG] {test_name} -  STDERR: {result.stderr}", end="")
            failed += 1

    print(f"{passed}/{total} PASSED - {failed}/{total} FAILED")

if __name__ == "__main__":
    main()