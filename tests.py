import os
import subprocess
import glob

TEST_DIR = "riscv-tests-isa"
EMULATOR = "zig-out/bin/mini_rv32_ima_zig"
EXTENSIONS = ["i", "m", "a"]

def elf_to_bin(ext):
    test_files = [f for f in glob.glob(f"{TEST_DIR}/{ext}/*") if not f.endswith('.dump')]

    for file in test_files:
        subprocess.run(["riscv64-unknown-elf-objcopy", "-O", "binary", file, f"{file}.bin"])

def main():
    for ext in EXTENSIONS:
        print("="*10 + f"TESTING RV32{ext.upper()}" + "="*10)
        test_files = [f for f in glob.glob(f"{TEST_DIR}/{ext}/*") if f.endswith('.bin')]
        print(f"Found {len(test_files)} tests in the test directory.")
        
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
                print(f"[HANG] {test_name}")
                failed += 1

        print(f"{passed}/{total} PASSED - {failed}/{total} FAILED", end="\n\n")

if __name__ == "__main__":
    main()