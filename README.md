# mini-rv32ima.zig
Tiny RISC-V emulator translated from C to Zig

This project is Zig translation of [cnlohr/mini-rv32ima](https://github.com/cnlohr/mini-rv32ima)

## Current State
The emulator currently passes 72/76 IMA test in [riscv-tests](https://github.com/riscv-software-src/riscv-tests)
```
$ zig test src/riscv_tests.zig
==========rv32i==========
[FAIL] rv32mi-p-pmpaddr.bin - Error: 3
57/58 PASSED - 1/58 FAILED

==========rv32m==========
8/8 PASSED - 0/8 FAILED

==========rv32a==========
10/10 PASSED - 0/10 FAILED

All 1 tests passed.
```

* The tests are filered by `rv32(m|u)(i|m|a)-p-*` to only included IMA tests.

**Improvements:** Fixed 4 failing test case.

## Why?

I basically needed embeddable risc-v emulator, [cnlohr/mini-rv32ima](https://github.com/cnlohr/mini-rv32ima) was a perfect fit as I didn't need 64bit or MMU. C is a great language but I want to embedded it in a zig project so I choose to rewrite.

Initially I tried line by line manual rewrite, but my lack knowledge made the process very difficult very. Later I started reading the risc-v spec & device tree spec and quickly realised, it would take me months to make anything functional and higher chance I would simply give up. So finally I opted for zig's builtin translate-c and manual rewrite on top.

## Long Term Goal
- [ ] RV32G compliant

## References 
- [cnlohr/mini-rv32ima](https://github.com/cnlohr/mini-rv32ima)
- [riscv-software-src/riscv-tests](https://github.com/riscv-software-src/riscv-tests)
- [ringtailsoftware/zig-minirv32](https://github.com/ringtailsoftware/zig-minirv32)