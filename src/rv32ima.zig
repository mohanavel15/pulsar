// translated using zig translate-c and manually tweaked.
// Too many casting... and other things. I hope eventually I'll clean up the code.

const std = @import("std");

pub const __helpers = @import("std").zig.c_translation.helpers;

pub export var INT32_MIN: c_int = -@as(c_int, 2147483647) - @as(c_int, 1);
pub export var RAM_IMAGE_OFFSET: c_int = @bitCast(@as(c_uint, @truncate(@as(c_uint, 2147483648))));

pub inline fn mmio_range(n: c_int) c_int {
    return @intFromBool((@as(c_int, 268435456) <= n) and (n < @as(c_int, 301989888)));
}

pub inline fn store_1_byte(ofs: u32, val: u32, image: [*c]u8) void {
    (image + ofs).* = @truncate(val);
}

pub inline fn store_2_bytes(ofs: u32, val: u32, image: [*c]u8) void {
    @as(*align(1) u16, @ptrCast(image + ofs)).* = @truncate(val);
}

pub inline fn store_4_bytes(ofs: u32, val: u32, image: [*c]u8) void {
    @as(*align(1) u32, @ptrCast(image + ofs)).* = val;
}

pub inline fn load_1_byte(ofs: u32, image: [*c]u8) u32 {
    return (image + ofs).*;
}

pub inline fn load_2_bytes(ofs: u32, image: [*c]u8) u32 {
    return @as(*align(1) u16, @ptrCast(image + ofs)).*;
}

pub inline fn load_4_bytes(ofs: u32, image: [*c]u8) u32 {
    return @as(*align(1) u32, @ptrCast(image + ofs)).*;
}

pub inline fn load_1_signed_byte(ofs: u32, image: [*c]u8) u32 {
    return @bitCast(@as(i32, @as(*align(1) i8, @ptrCast(image + ofs)).*));
}

pub inline fn load_2_signed_bytes(ofs: u32, image: [*c]u8) u32 {
    return @bitCast(@as(i32, @as(*align(1) i16, @ptrCast(image + ofs)).*));
}

pub const Handlers = struct {
    post_exec: *const fn (core: *NanoRV32IMA, pc: u32, ir: u32, retval: u32) void,
    control_store: *const fn (core: *NanoRV32IMA, addy: u32, val: u32) u32,
    control_load: *const fn (core: *NanoRV32IMA, addy: u32) u32,
    other_csr_write: *const fn (core: *NanoRV32IMA, image: [*c]u8, csrno: u16, value: u32) void,
    other_csr_read: *const fn (core: *NanoRV32IMA, image: [*c]u8, csrno: u16) i32,
};

pub const NanoRV32IMA = struct {
    regs: [32]u32 = std.mem.zeroes([32]u32),
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

    ram_size: c_int = 0,
    handlers: *Handlers,

    const Self = @This();

    pub fn init(ram_size: u32, handlers: *Handlers) Self {
        return Self{
            .ram_size = @intCast(ram_size),
            .handlers = handlers,
        };
    }

    pub fn step(self: *Self, image: [*c]u8, elapsedUs: u32, count: c_int) i32 {
        const new_timer: u32 = self.timerl +% elapsedUs;
        if (new_timer < self.timerl) {
            self.timerh +%= 1;
        }
        self.timerl = new_timer;
        if (((self.timerh > self.timermatchh) or ((self.timerh == self.timermatchh) and (self.timerl > self.timermatchl))) and ((self.timermatchh != 0) or (self.timermatchl != 0))) {
            self.extraflags &= @bitCast(@as(c_int, ~@as(c_int, 4)));
            self.mip |= @bitCast(@as(c_int, @as(c_int, 1) << @intCast(@as(c_int, 7))));
        } else {
            self.mip &= @bitCast(@as(c_int, ~(@as(c_int, 1) << @intCast(@as(c_int, 7)))));
        }
        if ((self.extraflags & @as(u32, 4)) != 0) return 1;
        var trap: u32 = 0;
        var rval: u32 = 0;
        var pc: u32 = self.pc;
        var cycle: u32 = self.cyclel;
        if ((@as(u32, @bitCast(@as(c_int, @intFromBool(((self.mip & @as(u32, @bitCast(@as(c_int, @as(c_int, 1) << @intCast(@as(c_int, 7)))))) != 0) and ((self.mie & @as(u32, @bitCast(@as(c_int, @as(c_int, 1) << @intCast(@as(c_int, 7)))))) != 0))))) != 0) and ((self.mstatus & @as(u32, 8)) != 0)) {
            trap = 2147483655;
            pc -%= 4;
        } else {
            var icount: c_int = 0;
            while (icount < count) : (icount += 1) {
                var ir: u32 = 0;
                rval = 0;
                cycle +%= 1;
                const ofs_pc: u32 = pc -% @as(u32, @bitCast(@as(c_int, RAM_IMAGE_OFFSET)));
                if (ofs_pc >= @as(u32, @bitCast(@as(c_int, self.ram_size)))) {
                    trap = @bitCast(@as(c_int, @as(c_int, 1) + @as(c_int, 1)));
                    break;
                } else if ((ofs_pc & @as(u32, 3)) != 0) {
                    trap = @bitCast(@as(c_int, @as(c_int, 1) + @as(c_int, 0)));
                    break;
                } else {
                    ir = load_4_bytes(ofs_pc, image);
                    var rdid: u32 = (ir >> @intCast(@as(u32, 7))) & @as(u32, 31);
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
                                    const imm: u32 = ir >> @intCast(@as(u32, 20));
                                    const imm_se: i32 = @bitCast(@as(c_uint, @truncate(imm | (if ((imm & @as(u32, 2048)) != 0) @as(c_uint, 4294963200) else @as(c_uint, 0)))));
                                    rval = pc +% @as(u32, 4);
                                    pc = ((self.regs[(ir >> @intCast(@as(u32, 15))) & @as(u32, 31)] +% @as(u32, @bitCast(@as(c_int, imm_se)))) & @as(u32, @bitCast(@as(c_int, ~@as(c_int, 1))))) -% @as(u32, 4);
                                    break;
                                }
                            },
                            @as(u32, 99) => {
                                {
                                    var immm4: u32 = ((((ir & @as(u32, 3840)) >> @intCast(@as(u32, 7))) | ((ir & @as(u32, 2113929216)) >> @intCast(@as(u32, 20)))) | ((ir & @as(u32, 128)) << @intCast(@as(u32, 4)))) | ((ir >> @intCast(@as(u32, 31))) << @intCast(@as(u32, 12)));
                                    if ((immm4 & @as(u32, 4096)) != 0) {
                                        immm4 |= 4294959104;
                                    }
                                    const rs1: i32 = @bitCast(@as(c_uint, @truncate(self.regs[(ir >> @intCast(@as(u32, 15))) & @as(u32, 31)])));
                                    const rs2: i32 = @bitCast(@as(c_uint, @truncate(self.regs[(ir >> @intCast(@as(u32, 20))) & @as(u32, 31)])));
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
                                    const rs1: u32 = self.regs[(ir >> @intCast(@as(u32, 15))) & @as(u32, 31)];
                                    const imm: u32 = ir >> @intCast(@as(u32, 20));
                                    const imm_se: i32 = @bitCast(@as(c_uint, @truncate(imm | (if ((imm & @as(u32, 2048)) != 0) @as(c_uint, 4294963200) else @as(c_uint, 0)))));
                                    var rsval: u32 = rs1 +% @as(u32, @bitCast(@as(c_int, imm_se)));
                                    rsval -%= @bitCast(@as(c_int, RAM_IMAGE_OFFSET));
                                    if (rsval >= @as(u32, @bitCast(@as(c_int, self.ram_size - @as(c_int, 3))))) {
                                        rsval +%= @bitCast(@as(c_int, RAM_IMAGE_OFFSET));
                                        if (mmio_range(@bitCast(@as(c_uint, @truncate(rsval)))) != 0) {
                                            rval = self.handlers.control_load(self, rsval);
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
                                    const rs1: u32 = self.regs[(ir >> @intCast(@as(u32, 15))) & @as(u32, 31)];
                                    const rs2: u32 = self.regs[(ir >> @intCast(@as(u32, 20))) & @as(u32, 31)];
                                    var addy: u32 = ((ir >> @intCast(@as(u32, 7))) & @as(u32, 31)) | ((ir & @as(c_uint, 4261412864)) >> @intCast(@as(u32, 20)));
                                    if ((addy & @as(u32, 2048)) != 0) {
                                        addy |= 4294963200;
                                    }
                                    addy +%= rs1 -% @as(u32, @bitCast(@as(c_int, RAM_IMAGE_OFFSET)));
                                    rdid = 0;
                                    if (addy >= @as(u32, @bitCast(@as(c_int, self.ram_size - @as(c_int, 3))))) {
                                        addy +%= @bitCast(@as(c_int, RAM_IMAGE_OFFSET));
                                        if (mmio_range(@bitCast(@as(c_uint, @truncate(addy)))) != 0) {
                                            if (self.handlers.control_store(self, addy, rs2) != 0) return @bitCast(@as(c_uint, @truncate(rs2)));
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
                                    imm = imm | (if ((imm & @as(u32, 2048)) != 0) @as(c_uint, 4294963200) else @as(c_uint, 0));
                                    const rs1: u32 = self.regs[(ir >> @intCast(@as(u32, 15))) & @as(u32, 31)];
                                    const is_reg: u32 = @bitCast(@as(c_int, @intFromBool(!!((ir & @as(u32, 32)) != 0))));
                                    const rs2: u32 = if (is_reg != 0) self.regs[imm & @as(u32, 31)] else imm;
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
                                                    const shift_amt: u5 = @intCast(rs2 & 31);
                                                    rval = if ((ir & 1073741824) != 0)
                                                        @bitCast(@as(i32, @bitCast(rs1)) >> shift_amt)
                                                    else
                                                        rs1 >> shift_amt;
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
                                    const csrno: u32 = ir >> @intCast(@as(u32, 20));
                                    const microop: u32 = (ir >> @intCast(@as(u32, 12))) & @as(u32, 7);
                                    if ((microop & @as(u32, 3)) != 0) {
                                        const rs1imm: c_int = @bitCast(@as(c_uint, @truncate((ir >> @intCast(@as(u32, 15))) & @as(u32, 31))));
                                        const rs1: u32 = self.regs[@bitCast(@as(isize, @intCast(rs1imm)))];
                                        var writeval: u32 = rs1;
                                        while (true) {
                                            switch (csrno) {
                                                @as(u32, 832) => {
                                                    rval = self.mscratch;
                                                    break;
                                                },
                                                @as(u32, 773) => {
                                                    rval = self.mtvec;
                                                    break;
                                                },
                                                @as(u32, 772) => {
                                                    rval = self.mie;
                                                    break;
                                                },
                                                @as(u32, 3072) => {
                                                    rval = cycle;
                                                    break;
                                                },
                                                @as(u32, 836) => {
                                                    rval = self.mip;
                                                    break;
                                                },
                                                @as(u32, 833) => {
                                                    rval = self.mepc;
                                                    break;
                                                },
                                                @as(u32, 768) => {
                                                    rval = self.mstatus;
                                                    break;
                                                },
                                                @as(u32, 834) => {
                                                    rval = self.mcause;
                                                    break;
                                                },
                                                @as(u32, 835) => {
                                                    rval = self.mtval;
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
                                                    rval = @bitCast(@as(c_int, self.handlers.other_csr_read(self, image, @truncate(csrno))));
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
                                                        self.mscratch = writeval;
                                                    }
                                                    break;
                                                },
                                                @as(u32, 773) => {
                                                    {
                                                        self.mtvec = writeval;
                                                    }
                                                    break;
                                                },
                                                @as(u32, 772) => {
                                                    {
                                                        self.mie = writeval;
                                                    }
                                                    break;
                                                },
                                                @as(u32, 836) => {
                                                    {
                                                        self.mip = writeval;
                                                    }
                                                    break;
                                                },
                                                @as(u32, 833) => {
                                                    {
                                                        self.mepc = writeval;
                                                    }
                                                    break;
                                                },
                                                @as(u32, 768) => {
                                                    {
                                                        self.mstatus = writeval;
                                                    }
                                                    break;
                                                },
                                                @as(u32, 834) => {
                                                    {
                                                        self.mcause = writeval;
                                                    }
                                                    break;
                                                },
                                                @as(u32, 835) => {
                                                    {
                                                        self.mtval = writeval;
                                                    }
                                                    break;
                                                },
                                                else => {
                                                    self.handlers.other_csr_write(self, image, @truncate(csrno), writeval);
                                                    break;
                                                },
                                            }
                                            break;
                                        }
                                    } else if (microop == @as(u32, 0)) {
                                        rdid = 0;
                                        if ((csrno & @as(u32, 255)) == @as(u32, 2)) {
                                            const startmstatus: u32 = self.mstatus;
                                            const startextraflags: u32 = self.extraflags;
                                            {
                                                self.mstatus = (((startmstatus & @as(u32, 128)) >> @intCast(@as(u32, 4))) | ((startextraflags & @as(u32, 3)) << @intCast(@as(u32, 11)))) | @as(u32, 128);
                                            }
                                            {
                                                self.extraflags = (startextraflags & @as(u32, @bitCast(@as(c_int, ~@as(c_int, 3))))) | ((startmstatus >> @intCast(@as(u32, 11))) & @as(u32, 3));
                                            }
                                            pc = self.mepc -% @as(u32, 4);
                                        } else {
                                            while (true) {
                                                switch (csrno) {
                                                    @as(u32, 0) => {
                                                        trap = @bitCast(@as(c_int, if ((self.extraflags & @as(u32, 3)) != 0) @as(c_int, 11) + @as(c_int, 1) else @as(c_int, 8) + @as(c_int, 1)));
                                                        break;
                                                    },
                                                    @as(u32, 1) => {
                                                        trap = @bitCast(@as(c_int, @as(c_int, 3) + @as(c_int, 1)));
                                                        break;
                                                    },
                                                    @as(u32, 261) => {
                                                        self.mstatus |= 8;
                                                        self.extraflags |= 4;
                                                        if (self.cyclel > cycle) {
                                                            self.cycleh +%= 1;
                                                        }
                                                        {
                                                            self.cyclel = cycle;
                                                        }
                                                        self.handlers.post_exec(self, pc, ir, trap);
                                                        {
                                                            self.pc = pc +% @as(u32, 4);
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
                                    var rs1: u32 = self.regs[(ir >> @intCast(@as(u32, 15))) & @as(u32, 31)];
                                    var rs2: u32 = self.regs[(ir >> @intCast(@as(u32, 20))) & @as(u32, 31)];
                                    const irmid: u32 = (ir >> @intCast(@as(u32, 27))) & @as(u32, 31);
                                    rs1 -%= @bitCast(@as(c_int, RAM_IMAGE_OFFSET));
                                    if (rs1 >= @as(u32, @bitCast(@as(c_int, self.ram_size - @as(c_int, 3))))) {
                                        trap = @bitCast(@as(c_int, @as(c_int, 7) + @as(c_int, 1)));
                                        rval = rs1 +% @as(u32, @bitCast(@as(c_int, RAM_IMAGE_OFFSET)));
                                    } else {
                                        rval = load_4_bytes(rs1, image);
                                        var dowrite: u32 = 1;
                                        while (true) {
                                            switch (irmid) {
                                                @as(u32, 2) => {
                                                    dowrite = 0;
                                                    self.extraflags = (self.extraflags & @as(u32, 7)) | (rs1 << @intCast(@as(u32, 3)));
                                                    break;
                                                },
                                                @as(u32, 3) => {
                                                    rval = @bitCast(@as(c_int, @intFromBool((self.extraflags >> @intCast(@as(u32, 3))) != (rs1 & @as(u32, 536870911)))));
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
                            self.pc = pc;
                        }
                        self.handlers.post_exec(self, pc, ir, trap);
                        break;
                    }
                    if (rdid != 0) {
                        {
                            self.regs[rdid] = rval;
                        }
                    }
                }
                self.handlers.post_exec(self, pc, ir, trap);
                pc +%= 4;
            }
        }
        if (trap != 0) {
            if ((trap & @as(c_uint, 2147483648)) != 0) {
                {
                    self.mcause = trap;
                }
                {
                    self.mtval = 0;
                }
                pc +%= 4;
            } else {
                {
                    self.mcause = trap -% @as(u32, 1);
                }
                {
                    self.mtval = if ((trap > @as(u32, 5)) and (trap <= @as(u32, 8))) rval else pc;
                }
            }
            {
                self.mepc = pc;
            }
            {
                self.mstatus = ((self.mstatus & @as(u32, 8)) << @intCast(@as(u32, 4))) | ((self.extraflags & @as(u32, 3)) << @intCast(@as(u32, 11)));
            }
            pc = self.mtvec -% @as(u32, 4);
            self.extraflags |= 3;
            trap = 0;
            pc +%= 4;
        }
        if (self.cyclel > cycle) {
            self.cycleh +%= 1;
        }
        {
            self.cyclel = cycle;
        }
        {
            self.pc = pc;
        }
        return 0;
    }
};
