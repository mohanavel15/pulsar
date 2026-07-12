const std = @import("std");
const Io = std.Io;
const default_64mb_dtb = @import("dtb.zig").default64mb;
const rv32ima = @import("rv32ima.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var gpa = init.gpa;

    const linux = "test_img/buildroot.img";

    const RAM_SIZE: u32 = 64 * 1024 * 1024;

    const ram_image = try gpa.alloc(u8, RAM_SIZE);
    defer gpa.free(ram_image);

    @memset(ram_image, 0);

    const img_conent = try std.Io.Dir.cwd().readFile(io, linux, ram_image);

    std.debug.print("{d} - {d}\n", .{ img_conent.len, ram_image.len });

    const dtb_offset = RAM_SIZE - default_64mb_dtb.len;
    @memcpy(ram_image[dtb_offset..], &default_64mb_dtb);

    var handlers = rv32ima.Handlers{
        .control_load = &control_load,
        .control_store = &control_store,
        .other_csr_read = &other_csr_read,
        .other_csr_write = &other_csr_write,
        .post_exec = &post_exec,
    };

    var core = rv32ima.NanoRV32IMA.init(RAM_SIZE, &handlers);
    core.pc = 0x80000000; //@intCast(rv32ima.RAM_IMAGE_OFFSET - 1);
    core.regs[10] = 0x00;
    core.regs[11] = 0x80000000 + @as(u32, @truncate(dtb_offset)); //  @as(u32, @intCast(rv32ima.RAM_IMAGE_OFFSET)) + @as(u32, @truncate(dtb_offset));
    core.extraflags |= 3;

    const time_divisor: u32 = 1;
    const instrs_per_flip: u32 = 1024;

    var lastTime: u32 = 0;

    var instct: isize = -1;
    var rt: u32 = 0;

    while (rt < instct + 1 or instct < 0) : (rt +%= instrs_per_flip) {
        var elapsedUs: u32 = 0;
        const this_ccount = &core.cyclel;
        elapsedUs = this_ccount.* / time_divisor - lastTime;
        lastTime += elapsedUs;

        const ret = core.step(@ptrCast(ram_image), elapsedUs, instrs_per_flip);
        switch (ret) {
            0 => {},
            1 => this_ccount.* += instrs_per_flip,
            3 => instct = 0,
            0x7777 => return, // {} goto restart; //syscon code for restart
            0x5555 => return, // printf( "POWEROFF@0x%08x%08x\n", core->cycleh, core->cyclel ); return 0; //syscon code for power-off
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
}

fn control_store(core: *rv32ima.NanoRV32IMA, addy: u32, val: u32) u32 {
    switch (addy) {
        0x10000000 => std.debug.print("{c}", .{@as(u8, @truncate(val))}),
        0x11004004 => core.timermatchh = val,
        0x11004000 => core.timermatchl = val,
        0x11100000 => {
            core.pc = core.pc + 4;
            return val;
        },
        else => {
            std.debug.print("CS: 0x{x}\n", .{addy});
        },
    }

    return 0;
}

fn control_load(core: *rv32ima.NanoRV32IMA, addy: u32) u32 {
    switch (addy) {
        0x1100bffc => return core.timerh,
        0x1100bff8 => return core.timerh,
        else => {
            std.debug.print("CL: 0x{x}\n", .{addy});
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
