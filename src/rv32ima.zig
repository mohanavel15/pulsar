const __root = @This();
pub const __builtin = @import("std").zig.c_translation.builtins;
pub const __helpers = @import("std").zig.c_translation.helpers;
pub export var INT32_MIN: c_int = -@as(c_int, 2147483647) - @as(c_int, 1);
pub export var RAM_SIZE: c_int = (@as(c_int, 2) * @as(c_int, 1024)) * @as(c_int, 1024);
pub export var RAM_IMAGE_OFFSET: c_int = @bitCast(@as(c_uint, @truncate(@as(c_uint, 2147483648))));
pub fn mmio_range(arg_n: c_int) callconv(.c) c_int {
    var n = arg_n;
    _ = &n;
    return @intFromBool((@as(c_int, 268435456) <= n) and (n < @as(c_int, 301989888)));
}
pub fn store_1_byte(arg_ofs: u32, arg_val: u32, arg_image: [*c]u8) callconv(.c) void {
    var ofs = arg_ofs;
    _ = &ofs;
    var val = arg_val;
    _ = &val;
    var image = arg_image;
    _ = &image;
    (image + ofs).* = @truncate(val);
}
pub fn store_2_bytes(arg_ofs: u32, arg_val: u32, arg_image: [*c]u8) callconv(.c) void {
    var ofs = arg_ofs;
    _ = &ofs;
    var val = arg_val;
    _ = &val;
    var image = arg_image;
    _ = &image;
    @as([*c]u16, @ptrCast(@alignCast(image + ofs))).* = @truncate(val);
}
pub fn store_4_bytes(arg_ofs: u32, arg_val: u32, arg_image: [*c]u8) callconv(.c) void {
    var ofs = arg_ofs;
    _ = &ofs;
    var val = arg_val;
    _ = &val;
    var image = arg_image;
    _ = &image;
    @as([*c]u32, @ptrCast(@alignCast(image + ofs))).* = val;
}
pub fn load_1_byte(arg_ofs: u32, arg_image: [*c]u8) callconv(.c) u32 {
    var ofs = arg_ofs;
    _ = &ofs;
    var image = arg_image;
    _ = &image;
    return (image + ofs).*;
}
pub fn load_2_bytes(arg_ofs: u32, arg_image: [*c]u8) callconv(.c) u32 {
    var ofs = arg_ofs;
    _ = &ofs;
    var image = arg_image;
    _ = &image;
    return @as([*c]u16, @ptrCast(@alignCast(image + ofs))).*;
}
pub fn load_4_bytes(arg_ofs: u32, arg_image: [*c]u8) callconv(.c) u32 {
    var ofs = arg_ofs;
    _ = &ofs;
    var image = arg_image;
    _ = &image;
    return @as([*c]u32, @ptrCast(@alignCast(image + ofs))).*;
}
pub fn load_1_signed_byte(arg_ofs: u32, arg_image: [*c]u8) callconv(.c) u32 {
    var ofs = arg_ofs;
    _ = &ofs;
    var image = arg_image;
    _ = &image;
    return @as([*c]i8, @ptrCast(@alignCast(image + ofs))).*;
}
pub fn load_2_signed_bytes(arg_ofs: u32, arg_image: [*c]u8) callconv(.c) u32 {
    var ofs = arg_ofs;
    _ = &ofs;
    var image = arg_image;
    _ = &image;
    return @bitCast(@as(c_int, @as([*c]i16, @ptrCast(@alignCast(image + ofs))).*));
}
pub extern fn handle_post_exec(pc: u32, ir: u32, retval: u32) void;
pub extern fn handle_control_store(addy: u32, val: u32) u32;
pub extern fn handle_control_load(addy: u32) u32;
pub extern fn handle_other_csr_write(image: [*c]u8, csrno: u16, value: u32) void;
pub extern fn handle_other_csr_read(image: [*c]u8, csrno: u16) i32;
pub const struct_MiniRV32IMAState = extern struct {
    regs: [32]u32 = @import("std").mem.zeroes([32]u32),
    pc: u32 = 0,
    mstatus: u32 = 0,
    cyclel: u32 = 0,
    cycleh: u32 = 0,
    timerl: u32 = 0,
    timerh: u32 = 0,
    timermatchl: u32 = 0,
    timermatchh: u32 = 0,
    mscratch: u32 = 0,
    mtvec: u32 = 0,
    mie: u32 = 0,
    mip: u32 = 0,
    mepc: u32 = 0,
    mtval: u32 = 0,
    mcause: u32 = 0,
    extraflags: u32 = 0,
    pub const MiniRV32IMAStep = __root.MiniRV32IMAStep;
};
pub fn MiniRV32IMAStep(arg_state: [*c]struct_MiniRV32IMAState, arg_image: [*c]u8, arg_vProcAddress: u32, arg_elapsedUs: u32, arg_count: c_int) callconv(.c) i32 {
    var state = arg_state;
    _ = &state;
    var image = arg_image;
    _ = &image;
    var vProcAddress = arg_vProcAddress;
    _ = &vProcAddress;
    var elapsedUs = arg_elapsedUs;
    _ = &elapsedUs;
    var count = arg_count;
    _ = &count;
    var new_timer: u32 = state.*.timerl +% elapsedUs;
    _ = &new_timer;
    if (new_timer < state.*.timerl) {
        state.*.timerh +%= 1;
    }
    state.*.timerl = new_timer;
    if (((state.*.timerh > state.*.timermatchh) or ((state.*.timerh == state.*.timermatchh) and (state.*.timerl > state.*.timermatchl))) and ((state.*.timermatchh != 0) or (state.*.timermatchl != 0))) {
        state.*.extraflags &= @bitCast(@as(c_int, ~@as(c_int, 4)));
        state.*.mip |= @bitCast(@as(c_int, @as(c_int, 1) << @intCast(@as(c_int, 7))));
    } else {
        state.*.mip &= @bitCast(@as(c_int, ~(@as(c_int, 1) << @intCast(@as(c_int, 7)))));
    }
    if ((state.*.extraflags & @as(u32, 4)) != 0) return 1;
    var trap: u32 = 0;
    _ = &trap;
    var rval: u32 = 0;
    _ = &rval;
    var pc: u32 = state.*.pc;
    _ = &pc;
    var cycle: u32 = state.*.cyclel;
    _ = &cycle;
    if ((@as(u32, @bitCast(@as(c_int, @intFromBool(((state.*.mip & @as(u32, @bitCast(@as(c_int, @as(c_int, 1) << @intCast(@as(c_int, 7)))))) != 0) and ((state.*.mie & @as(u32, @bitCast(@as(c_int, @as(c_int, 1) << @intCast(@as(c_int, 7)))))) != 0))))) != 0) and ((state.*.mstatus & @as(u32, 8)) != 0)) {
        trap = 2147483655;
        pc -%= 4;
    } else {
        var icount: c_int = 0;
        _ = &icount;
        while (icount < count) : (icount += 1) {
            var ir: u32 = 0;
            _ = &ir;
            rval = 0;
            cycle +%= 1;
            var ofs_pc: u32 = pc -% @as(u32, @bitCast(@as(c_int, RAM_IMAGE_OFFSET)));
            _ = &ofs_pc;
            if (ofs_pc >= @as(u32, @bitCast(@as(c_int, RAM_SIZE)))) {
                trap = @bitCast(@as(c_int, @as(c_int, 1) + @as(c_int, 1)));
                break;
            } else if ((ofs_pc & @as(u32, 3)) != 0) {
                trap = @bitCast(@as(c_int, @as(c_int, 1) + @as(c_int, 0)));
                break;
            } else {
                ir = load_4_bytes(ofs_pc, image);
                var rdid: u32 = (ir >> @intCast(@as(u32, 7))) & @as(u32, 31);
                _ = &rdid;
                while (true) {
                    switch (ir & @as(u32, 127)) {
                        @as(u32, 55) => {
                            rval = ir & @as(c_uint, 4294963200);
                            break;
                        },
                        @as(u32, 23) => {
                            rval = pc +% (ir & @as(c_uint, 4294963200));
                            break;
                        },
                        @as(u32, 111) => {
                            {
                                var reladdy: i32 = @bitCast(@as(c_uint, @truncate(((((ir & @as(c_uint, 2147483648)) >> @intCast(@as(u32, 11))) | ((ir & @as(u32, 2145386496)) >> @intCast(@as(u32, 20)))) | ((ir & @as(u32, 1048576)) >> @intCast(@as(u32, 9)))) | (ir & @as(u32, 1044480)))));
                                _ = &reladdy;
                                if ((reladdy & @as(c_int, 1048576)) != 0) {
                                    {
                                        const ref = &reladdy;
                                        ref.* = @bitCast(@as(c_uint, @truncate(@as(c_uint, @bitCast(@as(c_int, ref.*))) | @as(c_uint, 4292870144))));
                                    }
                                }
                                rval = pc +% @as(u32, 4);
                                pc = (pc +% @as(u32, @bitCast(@as(c_int, reladdy)))) -% @as(u32, 4);
                                break;
                            }
                        },
                        @as(u32, 103) => {
                            {
                                var imm: u32 = ir >> @intCast(@as(u32, 20));
                                _ = &imm;
                                var imm_se: i32 = @bitCast(@as(c_uint, @truncate(imm | (if ((imm & @as(u32, 2048)) != 0) @as(c_uint, 4294963200) else @as(c_uint, 0)))));
                                _ = &imm_se;
                                rval = pc +% @as(u32, 4);
                                pc = ((state.*.regs[(ir >> @intCast(@as(u32, 15))) & @as(u32, 31)] +% @as(u32, @bitCast(@as(c_int, imm_se)))) & @as(u32, @bitCast(@as(c_int, ~@as(c_int, 1))))) -% @as(u32, 4);
                                break;
                            }
                        },
                        @as(u32, 99) => {
                            {
                                var immm4: u32 = ((((ir & @as(u32, 3840)) >> @intCast(@as(u32, 7))) | ((ir & @as(u32, 2113929216)) >> @intCast(@as(u32, 20)))) | ((ir & @as(u32, 128)) << @intCast(@as(u32, 4)))) | ((ir >> @intCast(@as(u32, 31))) << @intCast(@as(u32, 12)));
                                _ = &immm4;
                                if ((immm4 & @as(u32, 4096)) != 0) {
                                    immm4 |= 4294959104;
                                }
                                var rs1: i32 = @bitCast(@as(c_uint, @truncate(state.*.regs[(ir >> @intCast(@as(u32, 15))) & @as(u32, 31)])));
                                _ = &rs1;
                                var rs2: i32 = @bitCast(@as(c_uint, @truncate(state.*.regs[(ir >> @intCast(@as(u32, 20))) & @as(u32, 31)])));
                                _ = &rs2;
                                immm4 = (pc +% immm4) -% @as(u32, 4);
                                rdid = 0;
                                while (true) {
                                    switch ((ir >> @intCast(@as(u32, 12))) & @as(u32, 7)) {
                                        @as(u32, 0) => {
                                            if (rs1 == rs2) {
                                                pc = immm4;
                                            }
                                            break;
                                        },
                                        @as(u32, 1) => {
                                            if (rs1 != rs2) {
                                                pc = immm4;
                                            }
                                            break;
                                        },
                                        @as(u32, 4) => {
                                            if (rs1 < rs2) {
                                                pc = immm4;
                                            }
                                            break;
                                        },
                                        @as(u32, 5) => {
                                            if (rs1 >= rs2) {
                                                pc = immm4;
                                            }
                                            break;
                                        },
                                        @as(u32, 6) => {
                                            if (@as(u32, @bitCast(@as(c_int, rs1))) < @as(u32, @bitCast(@as(c_int, rs2)))) {
                                                pc = immm4;
                                            }
                                            break;
                                        },
                                        @as(u32, 7) => {
                                            if (@as(u32, @bitCast(@as(c_int, rs1))) >= @as(u32, @bitCast(@as(c_int, rs2)))) {
                                                pc = immm4;
                                            }
                                            break;
                                        },
                                        else => {
                                            trap = @bitCast(@as(c_int, @as(c_int, 2) + @as(c_int, 1)));
                                        },
                                    }
                                    break;
                                }
                                break;
                            }
                        },
                        @as(u32, 3) => {
                            {
                                var rs1: u32 = state.*.regs[(ir >> @intCast(@as(u32, 15))) & @as(u32, 31)];
                                _ = &rs1;
                                var imm: u32 = ir >> @intCast(@as(u32, 20));
                                _ = &imm;
                                var imm_se: i32 = @bitCast(@as(c_uint, @truncate(imm | (if ((imm & @as(u32, 2048)) != 0) @as(c_uint, 4294963200) else @as(c_uint, 0)))));
                                _ = &imm_se;
                                var rsval: u32 = rs1 +% @as(u32, @bitCast(@as(c_int, imm_se)));
                                _ = &rsval;
                                rsval -%= @bitCast(@as(c_int, RAM_IMAGE_OFFSET));
                                if (rsval >= @as(u32, @bitCast(@as(c_int, RAM_SIZE - @as(c_int, 3))))) {
                                    rsval +%= @bitCast(@as(c_int, RAM_IMAGE_OFFSET));
                                    if (mmio_range(@bitCast(@as(c_uint, @truncate(rsval)))) != 0) {
                                        rval = handle_control_load(rsval);
                                    } else {
                                        trap = @bitCast(@as(c_int, @as(c_int, 5) + @as(c_int, 1)));
                                        rval = rsval;
                                    }
                                } else {
                                    while (true) {
                                        switch ((ir >> @intCast(@as(u32, 12))) & @as(u32, 7)) {
                                            @as(u32, 0) => {
                                                rval = load_1_signed_byte(rsval, image);
                                                break;
                                            },
                                            @as(u32, 1) => {
                                                rval = load_2_signed_bytes(rsval, image);
                                                break;
                                            },
                                            @as(u32, 2) => {
                                                rval = load_4_bytes(rsval, image);
                                                break;
                                            },
                                            @as(u32, 4) => {
                                                rval = load_1_byte(rsval, image);
                                                break;
                                            },
                                            @as(u32, 5) => {
                                                rval = load_2_bytes(rsval, image);
                                                break;
                                            },
                                            else => {
                                                trap = @bitCast(@as(c_int, @as(c_int, 2) + @as(c_int, 1)));
                                            },
                                        }
                                        break;
                                    }
                                }
                                break;
                            }
                        },
                        @as(u32, 35) => {
                            {
                                var rs1: u32 = state.*.regs[(ir >> @intCast(@as(u32, 15))) & @as(u32, 31)];
                                _ = &rs1;
                                var rs2: u32 = state.*.regs[(ir >> @intCast(@as(u32, 20))) & @as(u32, 31)];
                                _ = &rs2;
                                var addy: u32 = ((ir >> @intCast(@as(u32, 7))) & @as(u32, 31)) | ((ir & @as(c_uint, 4261412864)) >> @intCast(@as(u32, 20)));
                                _ = &addy;
                                if ((addy & @as(u32, 2048)) != 0) {
                                    addy |= 4294963200;
                                }
                                addy +%= rs1 -% @as(u32, @bitCast(@as(c_int, RAM_IMAGE_OFFSET)));
                                rdid = 0;
                                if (addy >= @as(u32, @bitCast(@as(c_int, RAM_SIZE - @as(c_int, 3))))) {
                                    addy +%= @bitCast(@as(c_int, RAM_IMAGE_OFFSET));
                                    if (mmio_range(@bitCast(@as(c_uint, @truncate(addy)))) != 0) {
                                        if (handle_control_store(addy, rs2) != 0) return @bitCast(@as(c_uint, @truncate(rs2)));
                                    } else {
                                        trap = @bitCast(@as(c_int, @as(c_int, 7) + @as(c_int, 1)));
                                        rval = addy;
                                    }
                                } else {
                                    while (true) {
                                        switch ((ir >> @intCast(@as(u32, 12))) & @as(u32, 7)) {
                                            @as(u32, 0) => {
                                                store_1_byte(addy, rs2, image);
                                                break;
                                            },
                                            @as(u32, 1) => {
                                                store_2_bytes(addy, rs2, image);
                                                break;
                                            },
                                            @as(u32, 2) => {
                                                store_4_bytes(addy, rs2, image);
                                                break;
                                            },
                                            else => {
                                                trap = @bitCast(@as(c_int, @as(c_int, 2) + @as(c_int, 1)));
                                            },
                                        }
                                        break;
                                    }
                                }
                                break;
                            }
                        },
                        @as(u32, 19), @as(u32, 51) => {
                            {
                                var imm: u32 = ir >> @intCast(@as(u32, 20));
                                _ = &imm;
                                imm = imm | (if ((imm & @as(u32, 2048)) != 0) @as(c_uint, 4294963200) else @as(c_uint, 0));
                                var rs1: u32 = state.*.regs[(ir >> @intCast(@as(u32, 15))) & @as(u32, 31)];
                                _ = &rs1;
                                var is_reg: u32 = @bitCast(@as(c_int, @intFromBool(!!((ir & @as(u32, 32)) != 0))));
                                _ = &is_reg;
                                var rs2: u32 = if (is_reg != 0) state.*.regs[imm & @as(u32, 31)] else imm;
                                _ = &rs2;
                                if ((is_reg != 0) and ((ir & @as(u32, 33554432)) != 0)) {
                                    while (true) {
                                        switch ((ir >> @intCast(@as(u32, 12))) & @as(u32, 7)) {
                                            @as(u32, 0) => {
                                                rval = rs1 *% rs2;
                                                break;
                                            },
                                            @as(u32, 1) => {
                                                rval = @bitCast(@as(c_int, @truncate((@as(i64, @as(i32, @bitCast(@as(c_uint, @truncate(rs1))))) * @as(i64, @as(i32, @bitCast(@as(c_uint, @truncate(rs2)))))) >> @intCast(@as(i64, 32)))));
                                                break;
                                            },
                                            @as(u32, 2) => {
                                                rval = @truncate((@as(u64, @bitCast(@as(c_long, @as(i64, @as(i32, @bitCast(@as(c_uint, @truncate(rs1)))))))) *% @as(u64, rs2)) >> @intCast(@as(u64, 32)));
                                                break;
                                            },
                                            @as(u32, 3) => {
                                                rval = @truncate((@as(u64, rs1) *% @as(u64, rs2)) >> @intCast(@as(u64, 32)));
                                                break;
                                            },
                                            @as(u32, 4) => {
                                                if (rs2 == @as(u32, 0)) {
                                                    rval = @bitCast(@as(c_int, -@as(c_int, 1)));
                                                } else {
                                                    rval = if ((@as(i32, @bitCast(@as(c_uint, @truncate(rs1)))) == INT32_MIN) and (@as(i32, @bitCast(@as(c_uint, @truncate(rs2)))) == -@as(c_int, 1))) rs1 else @as(u32, @bitCast(@as(c_int, @divTrunc(@as(i32, @bitCast(@as(c_uint, @truncate(rs1)))), @as(i32, @bitCast(@as(c_uint, @truncate(rs2))))))));
                                                }
                                                break;
                                            },
                                            @as(u32, 5) => {
                                                if (rs2 == @as(u32, 0)) {
                                                    rval = 4294967295;
                                                } else {
                                                    rval = rs1 / rs2;
                                                }
                                                break;
                                            },
                                            @as(u32, 6) => {
                                                if (rs2 == @as(u32, 0)) {
                                                    rval = rs1;
                                                } else {
                                                    rval = if ((@as(i32, @bitCast(@as(c_uint, @truncate(rs1)))) == INT32_MIN) and (@as(i32, @bitCast(@as(c_uint, @truncate(rs2)))) == -@as(c_int, 1))) @as(u32, 0) else @as(u32, @bitCast(@as(c_int, __helpers.signedRemainder(@as(i32, @bitCast(@as(c_uint, @truncate(rs1)))), @as(i32, @bitCast(@as(c_uint, @truncate(rs2))))))));
                                                }
                                                break;
                                            },
                                            @as(u32, 7) => {
                                                if (rs2 == @as(u32, 0)) {
                                                    rval = rs1;
                                                } else {
                                                    rval = rs1 % rs2;
                                                }
                                                break;
                                            },
                                            else => {},
                                        }
                                        break;
                                    }
                                } else {
                                    while (true) {
                                        switch ((ir >> @intCast(@as(u32, 12))) & @as(u32, 7)) {
                                            @as(u32, 0) => {
                                                rval = if ((is_reg != 0) and ((ir & @as(u32, 1073741824)) != 0)) rs1 -% rs2 else rs1 +% rs2;
                                                break;
                                            },
                                            @as(u32, 1) => {
                                                rval = rs1 << @intCast(rs2 & @as(u32, 31));
                                                break;
                                            },
                                            @as(u32, 2) => {
                                                rval = @bitCast(@as(c_int, @intFromBool(@as(i32, @bitCast(@as(c_uint, @truncate(rs1)))) < @as(i32, @bitCast(@as(c_uint, @truncate(rs2)))))));
                                                break;
                                            },
                                            @as(u32, 3) => {
                                                rval = @bitCast(@as(c_int, @intFromBool(rs1 < rs2)));
                                                break;
                                            },
                                            @as(u32, 4) => {
                                                rval = rs1 ^ rs2;
                                                break;
                                            },
                                            @as(u32, 5) => {
                                                rval = if ((ir & @as(u32, 1073741824)) != 0) @as(u32, @bitCast(@as(c_int, @as(i32, @bitCast(@as(c_uint, @truncate(rs1))))))) >> @intCast(rs2 & @as(u32, 31)) else rs1 >> @intCast(rs2 & @as(u32, 31));
                                                break;
                                            },
                                            @as(u32, 6) => {
                                                rval = rs1 | rs2;
                                                break;
                                            },
                                            @as(u32, 7) => {
                                                rval = rs1 & rs2;
                                                break;
                                            },
                                            else => {},
                                        }
                                        break;
                                    }
                                }
                                break;
                            }
                        },
                        @as(u32, 15) => {
                            rdid = 0;
                            break;
                        },
                        @as(u32, 115) => {
                            {
                                var csrno: u32 = ir >> @intCast(@as(u32, 20));
                                _ = &csrno;
                                var microop: u32 = (ir >> @intCast(@as(u32, 12))) & @as(u32, 7);
                                _ = &microop;
                                if ((microop & @as(u32, 3)) != 0) {
                                    var rs1imm: c_int = @bitCast(@as(c_uint, @truncate((ir >> @intCast(@as(u32, 15))) & @as(u32, 31))));
                                    _ = &rs1imm;
                                    var rs1: u32 = state.*.regs[@bitCast(@as(isize, @intCast(rs1imm)))];
                                    _ = &rs1;
                                    var writeval: u32 = rs1;
                                    _ = &writeval;
                                    while (true) {
                                        switch (csrno) {
                                            @as(u32, 832) => {
                                                rval = state.*.mscratch;
                                                break;
                                            },
                                            @as(u32, 773) => {
                                                rval = state.*.mtvec;
                                                break;
                                            },
                                            @as(u32, 772) => {
                                                rval = state.*.mie;
                                                break;
                                            },
                                            @as(u32, 3072) => {
                                                rval = cycle;
                                                break;
                                            },
                                            @as(u32, 836) => {
                                                rval = state.*.mip;
                                                break;
                                            },
                                            @as(u32, 833) => {
                                                rval = state.*.mepc;
                                                break;
                                            },
                                            @as(u32, 768) => {
                                                rval = state.*.mstatus;
                                                break;
                                            },
                                            @as(u32, 834) => {
                                                rval = state.*.mcause;
                                                break;
                                            },
                                            @as(u32, 835) => {
                                                rval = state.*.mtval;
                                                break;
                                            },
                                            @as(u32, 3857) => {
                                                rval = 4279234815;
                                                break;
                                            },
                                            @as(u32, 769) => {
                                                rval = 1077940481;
                                                break;
                                            },
                                            else => {
                                                rval = @bitCast(@as(c_int, handle_other_csr_read(image, @truncate(csrno))));
                                                break;
                                            },
                                        }
                                        break;
                                    }
                                    while (true) {
                                        switch (microop) {
                                            @as(u32, 1) => {
                                                writeval = rs1;
                                                break;
                                            },
                                            @as(u32, 2) => {
                                                writeval = rval | rs1;
                                                break;
                                            },
                                            @as(u32, 3) => {
                                                writeval = rval & ~rs1;
                                                break;
                                            },
                                            @as(u32, 5) => {
                                                writeval = @bitCast(@as(c_int, rs1imm));
                                                break;
                                            },
                                            @as(u32, 6) => {
                                                writeval = rval | @as(u32, @bitCast(@as(c_int, rs1imm)));
                                                break;
                                            },
                                            @as(u32, 7) => {
                                                writeval = rval & @as(u32, @bitCast(@as(c_int, ~rs1imm)));
                                                break;
                                            },
                                            else => {},
                                        }
                                        break;
                                    }
                                    while (true) {
                                        switch (csrno) {
                                            @as(u32, 832) => {
                                                {
                                                    state.*.mscratch = writeval;
                                                }
                                                break;
                                            },
                                            @as(u32, 773) => {
                                                {
                                                    state.*.mtvec = writeval;
                                                }
                                                break;
                                            },
                                            @as(u32, 772) => {
                                                {
                                                    state.*.mie = writeval;
                                                }
                                                break;
                                            },
                                            @as(u32, 836) => {
                                                {
                                                    state.*.mip = writeval;
                                                }
                                                break;
                                            },
                                            @as(u32, 833) => {
                                                {
                                                    state.*.mepc = writeval;
                                                }
                                                break;
                                            },
                                            @as(u32, 768) => {
                                                {
                                                    state.*.mstatus = writeval;
                                                }
                                                break;
                                            },
                                            @as(u32, 834) => {
                                                {
                                                    state.*.mcause = writeval;
                                                }
                                                break;
                                            },
                                            @as(u32, 835) => {
                                                {
                                                    state.*.mtval = writeval;
                                                }
                                                break;
                                            },
                                            else => {
                                                handle_other_csr_write(image, @truncate(csrno), writeval);
                                                break;
                                            },
                                        }
                                        break;
                                    }
                                } else if (microop == @as(u32, 0)) {
                                    rdid = 0;
                                    if ((csrno & @as(u32, 255)) == @as(u32, 2)) {
                                        var startmstatus: u32 = state.*.mstatus;
                                        _ = &startmstatus;
                                        var startextraflags: u32 = state.*.extraflags;
                                        _ = &startextraflags;
                                        {
                                            state.*.mstatus = (((startmstatus & @as(u32, 128)) >> @intCast(@as(u32, 4))) | ((startextraflags & @as(u32, 3)) << @intCast(@as(u32, 11)))) | @as(u32, 128);
                                        }
                                        {
                                            state.*.extraflags = (startextraflags & @as(u32, @bitCast(@as(c_int, ~@as(c_int, 3))))) | ((startmstatus >> @intCast(@as(u32, 11))) & @as(u32, 3));
                                        }
                                        pc = state.*.mepc -% @as(u32, 4);
                                    } else {
                                        while (true) {
                                            switch (csrno) {
                                                @as(u32, 0) => {
                                                    trap = @bitCast(@as(c_int, if ((state.*.extraflags & @as(u32, 3)) != 0) @as(c_int, 11) + @as(c_int, 1) else @as(c_int, 8) + @as(c_int, 1)));
                                                    break;
                                                },
                                                @as(u32, 1) => {
                                                    trap = @bitCast(@as(c_int, @as(c_int, 3) + @as(c_int, 1)));
                                                    break;
                                                },
                                                @as(u32, 261) => {
                                                    state.*.mstatus |= 8;
                                                    state.*.extraflags |= 4;
                                                    if (state.*.cyclel > cycle) {
                                                        state.*.cycleh +%= 1;
                                                    }
                                                    {
                                                        state.*.cyclel = cycle;
                                                    }
                                                    handle_post_exec(pc, ir, trap);
                                                    {
                                                        state.*.pc = pc +% @as(u32, 4);
                                                    }
                                                    return 1;
                                                },
                                                else => {
                                                    trap = @bitCast(@as(c_int, @as(c_int, 2) + @as(c_int, 1)));
                                                    break;
                                                },
                                            }
                                            break;
                                        }
                                    }
                                } else {
                                    trap = @bitCast(@as(c_int, @as(c_int, 2) + @as(c_int, 1)));
                                }
                                break;
                            }
                        },
                        @as(u32, 47) => {
                            {
                                var rs1: u32 = state.*.regs[(ir >> @intCast(@as(u32, 15))) & @as(u32, 31)];
                                _ = &rs1;
                                var rs2: u32 = state.*.regs[(ir >> @intCast(@as(u32, 20))) & @as(u32, 31)];
                                _ = &rs2;
                                var irmid: u32 = (ir >> @intCast(@as(u32, 27))) & @as(u32, 31);
                                _ = &irmid;
                                rs1 -%= @bitCast(@as(c_int, RAM_IMAGE_OFFSET));
                                if (rs1 >= @as(u32, @bitCast(@as(c_int, RAM_SIZE - @as(c_int, 3))))) {
                                    trap = @bitCast(@as(c_int, @as(c_int, 7) + @as(c_int, 1)));
                                    rval = rs1 +% @as(u32, @bitCast(@as(c_int, RAM_IMAGE_OFFSET)));
                                } else {
                                    rval = load_4_bytes(rs1, image);
                                    var dowrite: u32 = 1;
                                    _ = &dowrite;
                                    while (true) {
                                        switch (irmid) {
                                            @as(u32, 2) => {
                                                dowrite = 0;
                                                state.*.extraflags = (state.*.extraflags & @as(u32, 7)) | (rs1 << @intCast(@as(u32, 3)));
                                                break;
                                            },
                                            @as(u32, 3) => {
                                                rval = @bitCast(@as(c_int, @intFromBool((state.*.extraflags >> @intCast(@as(u32, 3))) != (rs1 & @as(u32, 536870911)))));
                                                dowrite = @bitCast(@as(c_int, @intFromBool(!(rval != 0))));
                                                break;
                                            },
                                            @as(u32, 1) => {
                                                break;
                                            },
                                            @as(u32, 0) => {
                                                rs2 +%= rval;
                                                break;
                                            },
                                            @as(u32, 4) => {
                                                rs2 ^= rval;
                                                break;
                                            },
                                            @as(u32, 12) => {
                                                rs2 &= rval;
                                                break;
                                            },
                                            @as(u32, 8) => {
                                                rs2 |= rval;
                                                break;
                                            },
                                            @as(u32, 16) => {
                                                rs2 = if (@as(i32, @bitCast(@as(c_uint, @truncate(rs2)))) < @as(i32, @bitCast(@as(c_uint, @truncate(rval))))) rs2 else rval;
                                                break;
                                            },
                                            @as(u32, 20) => {
                                                rs2 = if (@as(i32, @bitCast(@as(c_uint, @truncate(rs2)))) > @as(i32, @bitCast(@as(c_uint, @truncate(rval))))) rs2 else rval;
                                                break;
                                            },
                                            @as(u32, 24) => {
                                                rs2 = if (rs2 < rval) rs2 else rval;
                                                break;
                                            },
                                            @as(u32, 28) => {
                                                rs2 = if (rs2 > rval) rs2 else rval;
                                                break;
                                            },
                                            else => {
                                                trap = @bitCast(@as(c_int, @as(c_int, 2) + @as(c_int, 1)));
                                                dowrite = 0;
                                                break;
                                            },
                                        }
                                        break;
                                    }
                                    if (dowrite != 0) {
                                        store_4_bytes(rs1, rs2, image);
                                    }
                                }
                                break;
                            }
                        },
                        else => {
                            trap = @bitCast(@as(c_int, @as(c_int, 2) + @as(c_int, 1)));
                        },
                    }
                    break;
                }
                if (trap != 0) {
                    {
                        state.*.pc = pc;
                    }
                    handle_post_exec(pc, ir, trap);
                    break;
                }
                if (rdid != 0) {
                    {
                        state.*.regs[rdid] = rval;
                    }
                }
            }
            handle_post_exec(pc, ir, trap);
            pc +%= 4;
        }
    }
    if (trap != 0) {
        if ((trap & @as(c_uint, 2147483648)) != 0) {
            {
                state.*.mcause = trap;
            }
            {
                state.*.mtval = 0;
            }
            pc +%= 4;
        } else {
            {
                state.*.mcause = trap -% @as(u32, 1);
            }
            {
                state.*.mtval = if ((trap > @as(u32, 5)) and (trap <= @as(u32, 8))) rval else pc;
            }
        }
        {
            state.*.mepc = pc;
        }
        {
            state.*.mstatus = ((state.*.mstatus & @as(u32, 8)) << @intCast(@as(u32, 4))) | ((state.*.extraflags & @as(u32, 3)) << @intCast(@as(u32, 11)));
        }
        pc = state.*.mtvec -% @as(u32, 4);
        state.*.extraflags |= 3;
        trap = 0;
        pc +%= 4;
    }
    if (state.*.cyclel > cycle) {
        state.*.cycleh +%= 1;
    }
    {
        state.*.cyclel = cycle;
    }
    {
        state.*.pc = pc;
    }
    return 0;
}
