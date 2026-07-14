// translated using zig translate-c and manually tweaked.
// Too many casting... and other things. I hope eventually I'll clean up the code.

const std = @import("std");

pub const __helpers = @import("std").zig.c_translation.helpers;

pub export var INT32_MIN: c_int = -@as(c_int, 2147483647) - @as(c_int, 1);

pub var RAM_IMAGE_OFFSET: u32 = 0x80000000;

pub inline fn mmio_range(n: u32) bool {
    return 0x10000000 <= n and n < 0x12000000;
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

    ram_size: u32 = 0,
    handlers: *Handlers,

    const Self = @This();

    pub fn init(ram_size: u32, handlers: *Handlers) Self {
        return Self{
            .ram_size = ram_size,
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
            self.mip |= @bitCast(@as(c_int, @as(c_int, 1) << 7));
        } else {
            self.mip &= @bitCast(@as(c_int, ~(@as(c_int, 1) << 7)));
        }
        if ((self.extraflags & 4) != 0) return 1;
        var trap: u32 = 0;
        var rval: u32 = 0;
        var pc: u32 = self.pc;
        var cycle: u32 = self.cyclel;
        if ((@as(u32, @bitCast(@as(c_int, @intFromBool(((self.mip & @as(u32, @bitCast(@as(c_int, @as(c_int, 1) << 7)))) != 0) and ((self.mie & @as(u32, @bitCast(@as(c_int, @as(c_int, 1) << 7)))) != 0))))) != 0) and ((self.mstatus & 8) != 0)) {
            trap = 2147483655;
            pc -%= 4;
        } else {
            var icount: c_int = 0;
            while (icount < count) : (icount += 1) {
                var ir: u32 = 0;
                rval = 0;
                cycle +%= 1;
                const ofs_pc: u32 = pc -% RAM_IMAGE_OFFSET;
                if (ofs_pc >= self.ram_size) {
                    trap = 1 + 1;
                    break;
                } else if ((ofs_pc & 3) != 0) {
                    trap = 1 + 0;
                    break;
                } else {
                    ir = load_4_bytes(ofs_pc, image);
                    var rdid: u32 = (ir >> 7) & 31;

                    switch (ir & 0x7F) {
                        55 => rval = ir & @as(c_uint, 4294963200),
                        23 => rval = pc +% (ir & @as(c_uint, 4294963200)),
                        111 => {
                            var reladdy: i32 = @bitCast(@as(c_uint, @truncate(((((ir & RAM_IMAGE_OFFSET) >> 11) | ((ir & @as(u32, 2145386496)) >> 20)) | ((ir & @as(u32, 1048576)) >> @intCast(@as(u32, 9)))) | (ir & @as(u32, 1044480)))));
                            if ((reladdy & @as(c_int, 1048576)) != 0) {
                                const ref = &reladdy;
                                ref.* = @bitCast(@as(c_uint, @truncate(@as(c_uint, @bitCast(@as(c_int, ref.*))) | @as(c_uint, 4292870144))));
                            }
                            rval = pc +% 4;
                            pc = (pc +% @as(u32, @bitCast(@as(c_int, reladdy)))) -% 4;
                        },
                        103 => {
                            const imm: u32 = ir >> 20;
                            const imm_se: i32 = @bitCast(@as(c_uint, @truncate(imm | (if ((imm & @as(u32, 2048)) != 0) @as(c_uint, 4294963200) else @as(c_uint, 0)))));
                            rval = pc +% 4;
                            pc = ((self.regs[(ir >> 15) & 31] +% @as(u32, @bitCast(@as(c_int, imm_se)))) & @as(u32, @bitCast(@as(c_int, ~@as(c_int, 1))))) -% 4;
                        },
                        99 => {
                            var immm4: u32 = ((((ir & @as(u32, 3840)) >> 7) | ((ir & @as(u32, 2113929216)) >> 20)) | ((ir & @as(u32, 128)) << 4)) | ((ir >> @intCast(31)) << @intCast(@as(u32, 12)));
                            if ((immm4 & @as(u32, 4096)) != 0) {
                                immm4 |= 4294959104;
                            }

                            const rs1: i32 = @bitCast(@as(c_uint, @truncate(self.regs[(ir >> 15) & 31])));
                            const rs2: i32 = @bitCast(@as(c_uint, @truncate(self.regs[(ir >> 20) & 31])));
                            immm4 = (pc +% immm4) -% 4;
                            rdid = 0;

                            switch ((ir >> 12) & 7) {
                                0 => {
                                    if (rs1 == rs2) pc = immm4;
                                },
                                1 => {
                                    if (rs1 != rs2) pc = immm4;
                                },
                                4 => {
                                    if (rs1 < rs2) pc = immm4;
                                },
                                5 => {
                                    if (rs1 >= rs2) pc = immm4;
                                },
                                6 => {
                                    if (@as(u32, @bitCast(rs1)) < @as(u32, @bitCast(rs2))) pc = immm4;
                                },
                                7 => {
                                    if (@as(u32, @bitCast(rs1)) >= @as(u32, @bitCast(rs2))) pc = immm4;
                                },
                                else => {
                                    trap = 2 + 1;
                                },
                            }
                        },
                        3 => {
                            const rs1: u32 = self.regs[(ir >> 15) & 31];
                            const imm: u32 = ir >> 20;
                            const imm_se: i32 = @bitCast(@as(c_uint, @truncate(imm | (if ((imm & @as(u32, 2048)) != 0) @as(c_uint, 4294963200) else @as(c_uint, 0)))));
                            var rsval: u32 = rs1 +% @as(u32, @bitCast(imm_se));
                            rsval -%= RAM_IMAGE_OFFSET;
                            if (rsval >= (self.ram_size - 3)) {
                                rsval +%= RAM_IMAGE_OFFSET;
                                if (mmio_range(rsval)) {
                                    rval = self.handlers.control_load(self, rsval);
                                } else {
                                    trap = 5 + 1;
                                    rval = rsval;
                                }
                            } else {
                                switch ((ir >> 12) & 7) {
                                    0 => rval = load_1_signed_byte(rsval, image),
                                    1 => rval = load_2_signed_bytes(rsval, image),
                                    2 => rval = load_4_bytes(rsval, image),
                                    4 => rval = load_1_byte(rsval, image),
                                    5 => rval = load_2_bytes(rsval, image),
                                    else => trap = 2 + 1,
                                }
                            }
                        },
                        35 => {
                            const rs1: u32 = self.regs[(ir >> 15) & 31];
                            const rs2: u32 = self.regs[(ir >> 20) & 31];
                            var addy: u32 = ((ir >> 7) & 31) | ((ir & @as(c_uint, 4261412864)) >> 20);
                            if ((addy & @as(u32, 2048)) != 0) {
                                addy |= 4294963200;
                            }
                            addy +%= rs1 -% RAM_IMAGE_OFFSET;
                            rdid = 0;

                            // std.debug.print("TODO: Remove this after all the risc-v ima tests passes. \n", .{});
                            if (addy +% RAM_IMAGE_OFFSET == 0x80001000) {
                                _ = self.handlers.control_store(self, 0x80001000, rs2);
                            }

                            if (addy >= (self.ram_size - 3)) {
                                addy +%= RAM_IMAGE_OFFSET;
                                if (mmio_range(addy)) {
                                    if (self.handlers.control_store(self, addy, rs2) != 0) return @bitCast(@as(c_uint, @truncate(rs2)));
                                } else {
                                    trap = @bitCast(@as(c_int, @as(c_int, 7) + @as(c_int, 1)));
                                    rval = addy;
                                }
                            } else {
                                switch ((ir >> @intCast(@as(u32, 12))) & @as(u32, 7)) {
                                    0 => store_1_byte(addy, rs2, image),
                                    1 => store_2_bytes(addy, rs2, image),
                                    2 => store_4_bytes(addy, rs2, image),
                                    else => trap = 2 + 1,
                                }
                            }
                        },
                        19, 51 => {
                            var imm: u32 = ir >> 20;
                            imm = imm | (if ((imm & @as(u32, 2048)) != 0) @as(c_uint, 4294963200) else @as(c_uint, 0));
                            const rs1: u32 = self.regs[(ir >> 15) & 31];
                            const is_reg: u32 = @bitCast(@as(c_int, @intFromBool(!!((ir & @as(u32, 32)) != 0))));
                            const rs2: u32 = if (is_reg != 0) self.regs[imm & 31] else imm;
                            if ((is_reg != 0) and ((ir & @as(u32, 33554432)) != 0)) {
                                switch ((ir >> @intCast(@as(u32, 12))) & @as(u32, 7)) {
                                    0 => rval = rs1 *% rs2,
                                    1 => rval = @bitCast(@as(c_int, @truncate((@as(i64, @as(i32, @bitCast(@as(c_uint, @truncate(rs1))))) * @as(i64, @as(i32, @bitCast(@as(c_uint, @truncate(rs2)))))) >> @intCast(@as(i64, 32))))),
                                    2 => rval = @truncate((@as(u64, @bitCast(@as(c_long, @as(i64, @as(i32, @bitCast(@as(c_uint, @truncate(rs1)))))))) *% @as(u64, rs2)) >> @intCast(@as(u64, 32))),
                                    3 => rval = @truncate((@as(u64, rs1) *% @as(u64, rs2)) >> @intCast(@as(u64, 32))),
                                    4 => if (rs2 == 0) {
                                        rval = @bitCast(@as(c_int, -@as(c_int, 1)));
                                    } else {
                                        rval = if ((@as(i32, @bitCast(@as(c_uint, @truncate(rs1)))) == INT32_MIN) and (@as(i32, @bitCast(@as(c_uint, @truncate(rs2)))) == -@as(c_int, 1))) rs1 else @as(u32, @bitCast(@as(c_int, @divTrunc(@as(i32, @bitCast(@as(c_uint, @truncate(rs1)))), @as(i32, @bitCast(@as(c_uint, @truncate(rs2))))))));
                                    },
                                    5 => if (rs2 == 0) {
                                        rval = 4294967295;
                                    } else {
                                        rval = rs1 / rs2;
                                    },
                                    6 => if (rs2 == 0) {
                                        rval = rs1;
                                    } else {
                                        rval = if ((@as(i32, @bitCast(@as(c_uint, @truncate(rs1)))) == INT32_MIN) and (@as(i32, @bitCast(@as(c_uint, @truncate(rs2)))) == -@as(c_int, 1))) 0 else @as(u32, @bitCast(@as(c_int, __helpers.signedRemainder(@as(i32, @bitCast(@as(c_uint, @truncate(rs1)))), @as(i32, @bitCast(@as(c_uint, @truncate(rs2))))))));
                                    },
                                    7 => if (rs2 == 0) {
                                        rval = rs1;
                                    } else {
                                        rval = rs1 % rs2;
                                    },
                                    else => {},
                                }
                            } else {
                                switch ((ir >> @intCast(@as(u32, 12))) & @as(u32, 7)) {
                                    0 => rval = if ((is_reg != 0) and ((ir & @as(u32, 1073741824)) != 0)) rs1 -% rs2 else rs1 +% rs2,
                                    1 => rval = rs1 << @intCast(rs2 & 31),
                                    2 => rval = @intFromBool(@as(i32, @bitCast(@as(c_uint, @truncate(rs1)))) < @as(i32, @bitCast(@as(c_uint, @truncate(rs2))))),
                                    3 => rval = @intFromBool(rs1 < rs2),
                                    4 => rval = rs1 ^ rs2,
                                    5 => {
                                        const shift_amt: u5 = @intCast(rs2 & 31);
                                        rval = if ((ir & 1073741824) != 0)
                                            @bitCast(@as(i32, @bitCast(rs1)) >> shift_amt)
                                        else
                                            rs1 >> shift_amt;
                                    },
                                    6 => rval = rs1 | rs2,
                                    7 => rval = rs1 & rs2,
                                    else => {},
                                }
                            }
                        },
                        15 => rdid = 0,
                        115 => {
                            const csrno: u32 = ir >> 20;
                            const microop: u32 = (ir >> @intCast(@as(u32, 12))) & @as(u32, 7);
                            if ((microop & 3) != 0) {
                                const rs1imm: c_int = @bitCast(@as(c_uint, @truncate((ir >> 15) & 31)));
                                const rs1: u32 = self.regs[@bitCast(@as(isize, @intCast(rs1imm)))];
                                var writeval: u32 = rs1;

                                rval = switch (csrno) {
                                    832 => self.mscratch,
                                    773 => self.mtvec,
                                    772 => self.mie,
                                    3072 => cycle,
                                    836 => self.mip,
                                    833 => self.mepc,
                                    768 => self.mstatus,
                                    834 => self.mcause,
                                    835 => self.mtval,
                                    3857 => 4279234815,
                                    769 => 1077940481,
                                    else => @bitCast(self.handlers.other_csr_read(self, image, @truncate(csrno))),
                                };

                                writeval = switch (microop) {
                                    2 => rval | rs1,
                                    3 => rval & ~rs1,
                                    5 => @bitCast(rs1imm),
                                    6 => rval | @as(u32, @bitCast(@as(c_int, rs1imm))),
                                    7 => rval & @as(u32, @bitCast(@as(c_int, ~rs1imm))),
                                    else => rs1,
                                };

                                switch (csrno) {
                                    832 => self.mscratch = writeval,
                                    773 => self.mtvec = writeval,
                                    772 => self.mie = writeval,
                                    836 => self.mip = writeval,
                                    833 => self.mepc = writeval,
                                    768 => self.mstatus = writeval,
                                    834 => self.mcause = writeval,
                                    835 => self.mtval = writeval,
                                    else => self.handlers.other_csr_write(self, image, @truncate(csrno), writeval),
                                }
                            } else if (microop == 0) {
                                rdid = 0;
                                if ((csrno & 0xFF) == 2) {
                                    const startmstatus: u32 = self.mstatus;
                                    const startextraflags: u32 = self.extraflags;

                                    self.mstatus = (((startmstatus & @as(u32, 128)) >> 4) | ((startextraflags & 3) << 11)) | @as(u32, 128);
                                    self.extraflags = (startextraflags & @as(u32, @bitCast(@as(c_int, ~@as(c_int, 3))))) | ((startmstatus >> 11) & 3);

                                    pc = self.mepc -% 4;
                                } else {
                                    switch (csrno) {
                                        0 => trap = @bitCast(@as(c_int, if ((self.extraflags & 3) != 0) @as(c_int, 11) + @as(c_int, 1) else @as(c_int, 8) + @as(c_int, 1))),
                                        1 => trap = @bitCast(@as(c_int, @as(c_int, 3) + @as(c_int, 1))),
                                        261 => {
                                            self.mstatus |= 8;
                                            self.extraflags |= 4;
                                            if (self.cyclel > cycle) {
                                                self.cycleh +%= 1;
                                            }

                                            self.cyclel = cycle;
                                            self.handlers.post_exec(self, pc, ir, trap);

                                            self.pc = pc +% 4;

                                            return 1;
                                        },
                                        else => trap = 2 + 1,
                                    }
                                }
                            } else {
                                trap = 2 + 1;
                            }
                        },
                        47 => {
                            var rs1: u32 = self.regs[(ir >> 15) & 31];
                            var rs2: u32 = self.regs[(ir >> 20) & 31];
                            const irmid: u32 = (ir >> 27) & 31;

                            rs1 -%= RAM_IMAGE_OFFSET;

                            if (rs1 >= (self.ram_size - 3)) {
                                trap = 7 + 1;
                                rval = rs1 +% RAM_IMAGE_OFFSET;
                            } else {
                                rval = load_4_bytes(rs1, image);
                                var dowrite: u32 = 1;

                                switch (irmid) {
                                    2 => {
                                        dowrite = 0;
                                        self.extraflags = (self.extraflags & 7) | (rs1 << 3);
                                    },
                                    3 => {
                                        rval = @bitCast(@as(c_int, @intFromBool((self.extraflags >> 3) != (rs1 & @as(u32, 536870911)))));
                                        dowrite = @intFromBool(rval == 0);
                                    },
                                    1 => {},
                                    0 => rs2 +%= rval,
                                    4 => rs2 ^= rval,
                                    12 => rs2 &= rval,
                                    8 => rs2 |= rval,
                                    16 => rs2 = if (@as(i32, @bitCast(rs2)) < @as(i32, @bitCast(rval))) rs2 else rval,
                                    20 => rs2 = if (@as(i32, @bitCast(rs2)) > @as(i32, @bitCast(rval))) rs2 else rval,
                                    24 => rs2 = if (rs2 < rval) rs2 else rval,
                                    28 => rs2 = if (rs2 > rval) rs2 else rval,
                                    else => {
                                        trap = 2 + 1;
                                        dowrite = 0;
                                    },
                                }

                                if (dowrite != 0) store_4_bytes(rs1, rs2, image);
                            }
                        },
                        else => trap = 2 + 1,
                    }

                    if (trap != 0) {
                        self.pc = pc;
                        self.handlers.post_exec(self, pc, ir, trap);
                        break;
                    }
                    if (rdid != 0) {
                        self.regs[rdid] = rval;
                    }
                }
                self.handlers.post_exec(self, pc, ir, trap);
                pc +%= 4;
            }
        }
        if (trap != 0) {
            if ((trap & RAM_IMAGE_OFFSET) != 0) {
                self.mcause = trap;
                self.mtval = 0;
                pc +%= 4;
            } else {
                self.mcause = trap -% 1;
                self.mtval = if ((trap > 5) and (trap <= 8)) rval else pc;
            }

            self.mepc = pc;
            self.mstatus = ((self.mstatus & 8) << 4) | ((self.extraflags & 3) << 11);
            pc = self.mtvec -% 4;
            self.extraflags |= 3;
            trap = 0;
            pc +%= 4;
        }

        if (self.cyclel > cycle) {
            self.cycleh +%= 1;
        }

        self.cyclel = cycle;
        self.pc = pc;

        return 0;
    }
};
