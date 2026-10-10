# Pulsar
Pulsar is a tiny 32bit RISC-V emulator translated from C to Zig, based on [cnlohr/mini-rv32ima](https://github.com/cnlohr/mini-rv32ima).

## Current State
This emulator passes 75/76 IMA test in [riscv-tests](https://github.com/riscv-software-src/riscv-tests)

Currently Working on adding floating point extension.
```
$ zig test src/riscv_tests.zig
==========rv32i==========
[FAIL] rv32mi-p-pmpaddr.bin - Error: 3
57/58 PASSED - 1/58 FAILED

==========rv32m==========
8/8 PASSED - 0/8 FAILED

==========rv32a==========
10/10 PASSED - 0/10 FAILED

==========rv32f==========
[FAIL] rv32uf-p-fcmp.bin - Error: 1339
[FAIL] rv32uf-p-fmadd.bin - Error: 1339
[FAIL] rv32uf-p-recoding.bin - Error: 1337
[FAIL] rv32uf-p-fcvt_w.bin - Error: 1339
[FAIL] rv32uf-p-fcvt.bin - Error: 1339
[FAIL] rv32uf-p-fclass.bin - Error: 5
[FAIL] rv32uf-p-move.bin - Error: 11
[FAIL] rv32uf-p-fadd.bin - Error: 1339
[FAIL] rv32uf-p-fdiv.bin - Error: 1339
2/11 PASSED - 9/11 FAILED

All 1 tests passed.
```

* The tests are filered by `rv32(m|u)(i|m|a|f)-p-*` to only included IMA tests.

### Improvements:
- Fixed 4 IMA failing test case.
- started implementing RV32F.

## Why?

I basically needed embeddable risc-v emulator, [cnlohr/mini-rv32ima](https://github.com/cnlohr/mini-rv32ima) was a perfect fit as I didn't need 64bit or MMU. C is a great language but I want to embedded it in a zig project so I choose to rewrite.

Initially I tried line by line manual rewrite, but my lack knowledge made the process very difficult very. Later I started reading the risc-v spec & device tree spec and quickly realised, it would take me months to make anything functional and higher chance I would simply give up. So finally I opted for zig's builtin translate-c and manual rewrite on top.

## Long Term Goal
- [ ] RV32G (IMAFD, Zicsr, Zifencei extensions) compliant

## References 
- [cnlohr/mini-rv32ima](https://github.com/cnlohr/mini-rv32ima)
- [riscv-software-src/riscv-tests](https://github.com/riscv-software-src/riscv-tests)
- [ringtailsoftware/zig-minirv32](https://github.com/ringtailsoftware/zig-minirv32)
- [rvcodec.js](https://luplab.gitlab.io/rvcodecjs/)
- [rvopcode.com](https://rvopcode.com/en)