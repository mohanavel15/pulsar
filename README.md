# mini-rv32ima.zig
Tiny RISC-V emulator translated from C to Zig

This project is Zig translation of [cnlohr/mini-rv32ima](https://github.com/cnlohr/mini-rv32ima)

## Current State
The emulator currently passes 71/76 IMA test in [riscv-tests](https://github.com/riscv-software-src/riscv-tests)
```
$ python tests.py
Found 76 tests in the test directory.

[FAIL] rv32mi-p-illegal - STDERR: FAILED: 5
[FAIL] rv32mi-p-ma_fetch - STDERR: FAILED: 5
[FAIL] rv32mi-p-pmpaddr - STDERR: FAILED: 3
[FAIL] rv32ua-p-lrsc - STDERR: FAILED: 13
[HANG] rv32ui-p-ld_st
71/76 PASSED - 5/76 FAILED
```

* The tests are filered by `rv32(m|u)(i|m|a)-p-*` to only included IMA tests.

## Why?

I basically needed embeddable risc-v emulator, [cnlohr/mini-rv32ima](https://github.com/cnlohr/mini-rv32ima) was a perfect fit as I didn't need 64bit or MMU. C is a great language but I needed it to embedded in zig project so I choose to rewrite. 

Initially I tried line by line manual rewrite, but my lack knowledge made the process very difficult very. Later I tried reading the risc-v spec & device tree spec and quickly realised, it would take me months to make anything functional and higher chance I would simply give up. So finally I opted for zig's builtin translate-c and manual tweaking.

At this stage I want the pure zig emulator to boot linux kernel like in original repo, and I have no plan to alter any logic of translated code other than how the functionality is exposed outside. 