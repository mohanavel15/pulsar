# mini-rv32ima.zig
Tiny RISC-V emulator translated from C to Zig

This project is Zig translation of [cnlohr/mini-rv32ima](https://github.com/cnlohr/mini-rv32ima)

## WARNING: Still in early translation & clean up.

## Why?

I basically needed embeddable risc-v emulator, [cnlohr/mini-rv32ima](https://github.com/cnlohr/mini-rv32ima) was a perfect fit as I didn't need 64bit or MMU. C is a great language but I needed it to embedded in zig project so I choose to rewrite. 

Initially I tried line by line manual rewrite, but my lack knowledge made the process very difficult very. Later I tried reading the risc-v spec & device tree spec and quickly realised, it would take me months to make anything functional and higher chance I would simply give up. So finally I opted for zig's builtin translate-c and manual tweaking.

At this stage I want the pure zig emulator to boot linux kernel like in original repo, and I have no plan to alter any logic of translated code other than how the functionality is exposed outside. 