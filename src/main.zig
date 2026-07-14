const std = @import("std");
const Io = std.Io;
const default_64mb_dtb = @import("dtb.zig").default64mb;
const rv32ima = @import("rv32ima.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    const args = try init.minimal.args.toSlice(gpa);
    defer gpa.free(args);

    if (args.len < 2) {
        std.debug.print("$emulator [bin file to run]\n", .{});
        return;
    }

    const bin_file = args[1];

    const RAM_SIZE: u32 = 64 * 1024 * 1024;

    const ram_image = try gpa.alloc(u8, RAM_SIZE);
    defer gpa.free(ram_image);

    @memset(ram_image, 0);

    _ = try std.Io.Dir.cwd().readFile(io, bin_file, ram_image);

    const dtb_offset: u32 = RAM_SIZE - default_64mb_dtb.len;
    @memcpy(ram_image[dtb_offset..], &default_64mb_dtb);

    var handlers = rv32ima.Handlers{
        .control_load = &control_load,
        .control_store = &control_store,
        .other_csr_read = &other_csr_read,
        .other_csr_write = &other_csr_write,
        .post_exec = &post_exec,
    };

    var core = rv32ima.NanoRV32IMA.init(RAM_SIZE, &handlers);
    core.pc = rv32ima.RAM_IMAGE_OFFSET;
    core.regs[10] = 0x00;
    core.regs[11] = rv32ima.RAM_IMAGE_OFFSET + dtb_offset;
    core.extraflags |= 3;

    const time_divisor: u32 = 1;
    const instrs_per_flip: u32 = 1024;
    // const instrs_per_flip: u32 = 1;

    var instct: i32 = -1;
    var lastTime: u32 = 0;
    var rt: u32 = 0;

    while (rt < instct + 1 or instct < 0) : (rt +%= instrs_per_flip) {
        var elapsedUs: u32 = 0;
        const this_ccount = &core.cyclel;
        elapsedUs = (this_ccount.* / time_divisor) -% lastTime;
        lastTime +%= elapsedUs;

        if (instrs_per_flip == 1) {
            dump_states(&core, ram_image);
        }

        const ret = core.step(@ptrCast(ram_image), elapsedUs, instrs_per_flip);
        switch (ret) {
            0 => {},
            1 => this_ccount.* +%= instrs_per_flip, // Sleep here?
            3 => instct = 0,
            0x7777 => return, // {} goto restart; //syscon code for restart
            0x5555 => {
                std.debug.print("POWEROFF@0x{x:0>8}{x:0>8}\n", .{ core.cycleh, core.cyclel });
                return;
            },
            else => {
                std.debug.print("Unknow RET: {d}\n", .{ret});
            },
        }
    }
}

fn post_exec(core: *rv32ima.NanoRV32IMA, pc: u32, ir: u32, retval: u32) void {
    _ = core;
    _ = pc;
    _ = ir;
    _ = retval;

    // std.debug.print("PC: {x:0>8} | IR: {x:0>8}\n", .{ pc, ir });
}

fn control_store(core: *rv32ima.NanoRV32IMA, addy: u32, val: u32) u32 {
    switch (addy) {
        0x80001000 => {
            if (val == 1) {
                std.debug.print("PASSED\n", .{});
                std.process.exit(0);
            } else {
                std.debug.print("FAILED: {d}\n", .{val});
                std.process.exit(1);
            }
        },
        0x10000000 => std.debug.print("{c}", .{@as(u8, @truncate(val))}),
        0x11004004 => core.timermatchh = val,
        0x11004000 => core.timermatchl = val,
        0x11100000 => {
            core.pc = core.pc + 4;
            return val;
        },
        else => {
            std.debug.print("CS: 0x{x:0>8}\n", .{addy});
        },
    }

    return 0;
}

fn control_load(core: *rv32ima.NanoRV32IMA, addy: u32) u32 {
    switch (addy) {
        0x10000005 => return 0x60,
        0x1100bffc => return core.timerh,
        0x1100bff8 => return core.timerl,
        else => {
            std.debug.print("CL: 0x{x:0>8}\n", .{addy});
        },
    }

    return 0;
}

fn other_csr_write(core: *rv32ima.NanoRV32IMA, image: [*c]u8, csrno: u16, value: u32) void {
    _ = core;
    _ = image;
    _ = csrno;
    _ = value;
}

fn other_csr_read(core: *rv32ima.NanoRV32IMA, image: [*c]u8, csrno: u16) i32 {
    _ = core;
    _ = image;
    _ = csrno;
    return 0;
}

fn dump_states(core: *rv32ima.NanoRV32IMA, image: []u8) void {
    std.debug.print("PC: {x:0>8} ", .{core.pc});

    const pc_offset = core.pc - rv32ima.RAM_IMAGE_OFFSET;
    if (pc_offset >= 0 and pc_offset < core.ram_size - 3) {
        std.debug.print("[0x{x:0>8}] ", .{@as([*]u32, @ptrCast(@alignCast(image.ptr + pc_offset)))[0]});
    } else {
        std.debug.print("[xxxxxxxxxx] ", .{});
    }

    const regs = core.regs;
    std.debug.print("Z:{x:0>8} ra:{x:0>8} sp:{x:0>8} gp:{x:0>8} tp:{x:0>8} t0:{x:0>8} t1:{x:0>8} t2:{x:0>8} s0:{x:0>8} s1:{x:0>8} a0:{x:0>8} a1:{x:0>8} a2:{x:0>8} a3:{x:0>8} a4:{x:0>8} a5:{x:0>8} a6:{x:0>8} a7:{x:0>8} s2:{x:0>8} s3:{x:0>8} s4:{x:0>8} s5:{x:0>8} s6:{x:0>8} s7:{x:0>8} s8:{x:0>8} s9:{x:0>8} s10:{x:0>8} s11:{x:0>8} t3:{x:0>8} t4:{x:0>8} t5:{x:0>8} t6:{x:0>8}\n", .{ regs[0], regs[1], regs[2], regs[3], regs[4], regs[5], regs[6], regs[7], regs[8], regs[9], regs[10], regs[11], regs[12], regs[13], regs[14], regs[15], regs[16], regs[17], regs[18], regs[19], regs[20], regs[21], regs[22], regs[23], regs[24], regs[25], regs[26], regs[27], regs[28], regs[29], regs[30], regs[31] });
}
