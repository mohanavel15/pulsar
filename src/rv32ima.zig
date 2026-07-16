// translated using zig translate-c and manually tweaked.
// Too many casting... and other things. I hope eventually I'll clean up the code.

const std = @import("std");

pub const RAM_IMAGE_OFFSET: u32 = 0x80000000;

pub inline fn mmio_range(n: u32) bool {
    return 0x10000000 <= n and n < 0x12000000;
}

pub inline fn store(T: type, ofs: u32, val: u32, ptr: []u8) void {
    @as(*align(1) T, @ptrCast(&ptr[ofs])).* = @truncate(val);
}

pub inline fn load(T: type, ofs: u32, ptr: []u8) u32 {
    return @as(*align(1) T, @ptrCast(&ptr[ofs])).*;
}

pub inline fn load_signed(T: type, ofs: u32, ptr: []u8) u32 {
    return @bitCast(@as(i32, @as(*align(1) T, @ptrCast(&ptr[ofs])).*));
}

pub const Handlers = struct {
    post_exec: *const fn (core: *NanoRV32IMA, pc: u32, ir: u32, retval: u32) void,
    control_store: *const fn (core: *NanoRV32IMA, addy: u32, val: u32) u32,
    control_load: *const fn (core: *NanoRV32IMA, addy: u32) u32,
    other_csr_write: *const fn (core: *NanoRV32IMA, ptr: []u8, csrno: u16, value: u32) void,
    other_csr_read: *const fn (core: *NanoRV32IMA, ptr: []u8, csrno: u16) i32,
};

pub const NanoRV32IMA = struct {
    regs: [32]u32 = std.mem.zeroes([32]u32),
    pc: u32 = RAM_IMAGE_OFFSET,
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
    extraflags: u32 = 3, // Machine Mode

    handlers: *Handlers,
    ram: []u8,

    const Self = @This();

    pub fn init(handlers: *Handlers, ram: []u8) Self {
        return Self{
            .handlers = handlers,
            .ram = ram,
        };
    }

    pub fn step(self: *Self, elapsedUs: u32, count: u32) i32 {
        const new_timer: u32 = self.timerl +% elapsedUs;
        if (new_timer < self.timerl) self.timerh +%= 1;
        self.timerl = new_timer;

        if (((self.timerh > self.timermatchh) or ((self.timerh == self.timermatchh) and (self.timerl > self.timermatchl))) and ((self.timermatchh != 0) or (self.timermatchl != 0))) {
            self.extraflags &= ~@as(u32, 4);
            self.mip |= @as(u32, 1 << 7);
        } else {
            self.mip &= ~@as(u32, 1 << 7);
        }

        if ((self.extraflags & 4) != 0) return 1;
        var trap: u32 = 0;
        var rval: u32 = 0;
        var pc: u32 = self.pc;
        var cycle: u32 = self.cyclel;

        if ((self.mip & (1 << 7)) != 0 and (self.mie & (1 << 7)) != 0 and (self.mstatus & 0x8) != 0) {
            // Timer interrupt.
            trap = 0x80000007;
            pc -%= 4;
        } else {
            var icount: u32 = 0;
            while (icount < count) : (icount += 1) {
                var ir: u32 = 0;
                rval = 0;
                cycle +%= 1;
                const ofs_pc: u32 = pc -% RAM_IMAGE_OFFSET;
                if (ofs_pc >= self.ram.len) {
                    trap = 1 + 1;
                    break;
                } else if ((ofs_pc & 3) != 0) {
                    trap = 1 + 0;
                    break;
                } else {
                    ir = load(u32, ofs_pc, self.ram);
                    var rdid: u32 = (ir >> 7) & 31;

                    switch (ir & 0x7F) {
                        0x37 => rval = ir & 0xFFFFF000, // LUI (0b0110111)
                        0x17 => rval = pc +% (ir & 0xFFFFF000), // AUIPC (0b0010111)
                        0x6F => { // JAL (0b1101111)
                            var reladdy: u32 = ((ir & 0x80000000) >> 11) | ((ir & 0x7fe00000) >> 20) | ((ir & 0x00100000) >> 9) | ((ir & 0x000ff000));
                            if ((reladdy & 0x100000) != 0) reladdy |= 0xFFE00000;
                            rval = pc +% 4;
                            pc = pc +% reladdy -% 4;
                        },
                        0x67 => { // JALR (0b1100111)
                            const imm: u32 = ir >> 20;
                            const imm_se: u32 = imm | @as(u32, if ((imm & 0x800) != 0) 0xFFFFF000 else 0);
                            rval = pc +% 4;

                            pc = ((self.regs[(ir >> 15) & 0x1F] +% imm_se) & ~@as(u32, 1)) -% 4;
                        },
                        0x63 => { // Branch (0b1100011)
                            var immm4: u32 = ((ir & 0xF00) >> 7) | ((ir & 0x7E000000) >> 20) | ((ir & 0x80) << 4) | ((ir >> 31) << 12);
                            if ((immm4 & 0x1000) != 0) immm4 |= 0xFFFFE000;

                            const rs1 = self.regs[(ir >> 15) & 0x1F];
                            const rs2 = self.regs[(ir >> 20) & 0x1F];
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
                                    if (@as(i32, @bitCast(rs1)) < @as(i32, @bitCast(rs2))) pc = immm4;
                                },
                                5 => {
                                    if (@as(i32, @bitCast(rs1)) >= @as(i32, @bitCast(rs2))) pc = immm4;
                                },
                                6 => {
                                    if (rs1 < rs2) pc = immm4;
                                },
                                7 => {
                                    if (rs1 >= rs2) pc = immm4;
                                },
                                else => {
                                    trap = 2 + 1;
                                },
                            }
                        },
                        0x03 => { // Load (0b0000011)
                            const rs1: u32 = self.regs[(ir >> 15) & 31];
                            const imm: u32 = ir >> 20;
                            const imm_se: u32 = imm | @as(u32, if ((imm & 0x800) != 0) 0xFFFFF000 else 0);

                            var rsval: u32 = rs1 +% imm_se;

                            rsval -%= RAM_IMAGE_OFFSET;
                            if (rsval >= (self.ram.len - 3)) {
                                rsval +%= RAM_IMAGE_OFFSET;
                                if (mmio_range(rsval)) {
                                    rval = self.handlers.control_load(self, rsval);
                                } else {
                                    trap = 5 + 1;
                                    rval = rsval;
                                }
                            } else {
                                switch ((ir >> 12) & 7) {
                                    0 => rval = load_signed(i8, rsval, self.ram),
                                    1 => rval = load_signed(i16, rsval, self.ram),
                                    2 => rval = load(u32, rsval, self.ram),
                                    4 => rval = load(u8, rsval, self.ram),
                                    5 => rval = load(u16, rsval, self.ram),
                                    else => trap = 2 + 1,
                                }
                            }
                        },
                        0x23 => { // Store 0b0100011
                            const rs1: u32 = self.regs[(ir >> 15) & 31];
                            const rs2: u32 = self.regs[(ir >> 20) & 31];
                            var addy: u32 = ((ir >> 7) & 31) | ((ir & 0xFE000000) >> 20);
                            if ((addy & 0x800) != 0) addy |= 0xFFFFF000;

                            addy +%= rs1 -% RAM_IMAGE_OFFSET;
                            rdid = 0;

                            // std.debug.print("TODO: Remove this after all the risc-v ima tests passes. \n", .{});
                            if (addy +% RAM_IMAGE_OFFSET == 0x80001000) {
                                _ = self.handlers.control_store(self, 0x80001000, rs2);
                            }

                            if (addy >= (self.ram.len - 3)) {
                                addy +%= RAM_IMAGE_OFFSET;
                                if (mmio_range(addy)) {
                                    if (self.handlers.control_store(self, addy, rs2) != 0) return @bitCast(rs2);
                                } else {
                                    trap = 7 + 1;
                                    rval = addy;
                                }
                            } else {
                                switch ((ir >> @intCast(@as(u32, 12))) & @as(u32, 7)) {
                                    0 => store(u8, addy, rs2, self.ram),
                                    1 => store(u16, addy, rs2, self.ram),
                                    2 => store(u32, addy, rs2, self.ram),
                                    else => trap = 2 + 1,
                                }
                            }
                        },
                        0x13, 0x33 => { // Op-immediate 0b0010011, // Op 0b0110011
                            var imm: u32 = ir >> 20;
                            imm |= @as(u32, if ((imm & 0x800) != 0) 0xFFFFF000 else 0);

                            const rs1: u32 = self.regs[(ir >> 15) & 31];
                            const is_reg: u32 = @bitCast(@as(c_int, @intFromBool(!!((ir & @as(u32, 32)) != 0))));
                            const rs2: u32 = if (is_reg != 0) self.regs[imm & 31] else imm;
                            if ((is_reg != 0) and ((ir & @as(u32, 33554432)) != 0)) {
                                switch ((ir >> 12) & 7) {
                                    0 => rval = rs1 *% rs2,
                                    1 => rval = @bitCast(@as(c_int, @truncate((@as(i64, @as(i32, @bitCast(@as(c_uint, @truncate(rs1))))) * @as(i64, @as(i32, @bitCast(@as(c_uint, @truncate(rs2)))))) >> @intCast(@as(i64, 32))))),
                                    2 => rval = @truncate(@as(u64, @bitCast(@as(i64, @as(i32, @bitCast(rs1))))) *% @as(u64, rs2) >> 32),
                                    3 => rval = @truncate((@as(u64, rs1) *% @as(u64, rs2)) >> 32),
                                    4 => if (rs2 == 0) {
                                        rval = @bitCast(@as(i32, -1));
                                    } else {
                                        if ((@as(i32, @bitCast(rs1)) == std.math.minInt(i32)) and (@as(i32, @bitCast(rs2))) == -1) {
                                            rval = rs1;
                                        } else {
                                            rval = @as(u32, @bitCast(@as(c_int, @divTrunc(@as(i32, @bitCast(@as(c_uint, @truncate(rs1)))), @as(i32, @bitCast(@as(c_uint, @truncate(rs2))))))));
                                        }
                                    },
                                    5 => if (rs2 == 0) {
                                        rval = 4294967295;
                                    } else {
                                        rval = rs1 / rs2;
                                    },
                                    6 => if (rs2 == 0) {
                                        rval = rs1;
                                    } else {
                                        if ((@as(i32, @bitCast(rs1)) == std.math.minInt(i32)) and (@as(i32, @bitCast(rs2))) == -1) {
                                            rval = 0;
                                        } else {
                                            rval = @bitCast(@rem(@as(i32, @bitCast(rs1)), @as(i32, @bitCast(rs2))));
                                        }
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
                        0x0F => rdid = 0,
                        0x73 => { // Zifencei+Zicsr  (0b1110011)
                            const csrno: u32 = ir >> 20;
                            const microop: u32 = (ir >> 12) & 7;
                            if ((microop & 3) != 0) {
                                const rs1imm: u32 = (ir >> 15) & 31;
                                const rs1: u32 = self.regs[rs1imm];
                                var writeval: u32 = rs1;

                                rval = switch (csrno) {
                                    0x340 => self.mscratch,
                                    0x305 => self.mtvec,
                                    0x304 => self.mie,
                                    0xC00 => cycle,
                                    0x344 => self.mip,
                                    0x341 => self.mepc,
                                    0x300 => self.mstatus,
                                    0x342 => self.mcause,
                                    0x343 => self.mtval,
                                    0xF11 => 0xFF0FF0FF, //mvendorid
                                    0x301 => 0x40401101, //misa (XLEN=32, IMA+X)
                                    // 0x3B0 => 0, //pmpaddr0
                                    // 0x3a0 => 0, //pmpcfg0
                                    // 0xF12 => 0x00000000, //marchid
                                    // 0xF13 => 0x00000000, //mimpid
                                    // 0xF14 => 0x00000000, //mhartid
                                    else => @bitCast(self.handlers.other_csr_read(self, self.ram, @truncate(csrno))),
                                };

                                writeval = switch (microop) {
                                    1 => rs1, //CSRRW
                                    2 => rval | rs1, //CSRRS
                                    3 => rval & ~rs1, //CSRRC
                                    5 => rs1imm, //CSRRWI
                                    6 => rval | rs1imm, //CSRRSI
                                    7 => rval & ~rs1imm, //CSRRCI
                                    else => unreachable,
                                };

                                switch (csrno) {
                                    0x340 => self.mscratch = writeval,
                                    0x305 => self.mtvec = writeval,
                                    0x304 => self.mie = writeval,
                                    0x344 => self.mip = writeval,
                                    0x341 => self.mepc = writeval,
                                    0x300 => self.mstatus = writeval,
                                    0x342 => self.mcause = writeval,
                                    0x343 => self.mtval = writeval,
                                    // case 0x3a0: {}, //pmpcfg0
                                    // case 0x3B0: {}, //pmpaddr0
                                    // case 0xF11: {}, //mvendorid
                                    // case 0xF12: {}, //marchid
                                    // case 0xF13: {}, //mimpid
                                    // case 0xF14: {}, //mhartid
                                    // case 0x301: {}, //misa
                                    else => self.handlers.other_csr_write(self, self.ram, @truncate(csrno), writeval),
                                }
                            } else if (microop == 0x0) { // "SYSTEM" 0b000
                                rdid = 0;
                                if ((csrno & 0xFF) == 2) { // MRET
                                    const startmstatus: u32 = self.mstatus;
                                    const startextraflags: u32 = self.extraflags;

                                    self.mstatus = ((startmstatus & 0x80) >> 4) | ((startextraflags & 3) << 11) | 0x80;
                                    self.extraflags = (startextraflags & ~@as(u32, 3)) | ((startmstatus >> 11) & 3);

                                    pc = self.mepc -% 4;
                                } else {
                                    switch (csrno) {
                                        0 => trap = if ((self.extraflags & 3) != 0) 11 + 1 else 8 + 1,
                                        1 => trap = 3 + 1,
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
                        0x2F => { // RV32A (0b00101111)
                            var rs1: u32 = self.regs[(ir >> 15) & 31];
                            var rs2: u32 = self.regs[(ir >> 20) & 31];
                            const irmid: u32 = (ir >> 27) & 31;

                            rs1 -%= RAM_IMAGE_OFFSET;

                            if (rs1 >= (self.ram.len - 3)) {
                                trap = 7 + 1;
                                rval = rs1 +% RAM_IMAGE_OFFSET;
                            } else {
                                rval = load(u32, rs1, self.ram);
                                var dowrite: u32 = 1;
                                switch (irmid) {
                                    2 => {
                                        dowrite = 0;
                                        self.extraflags = (self.extraflags & 7) | (rs1 << 3);
                                    },
                                    3 => {
                                        rval = @intFromBool((self.extraflags >> 3) != (rs1 & 0x1FFFFFFF));
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

                                if (dowrite != 0) store(u32, rs1, rs2, self.ram);
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
            if ((trap & 0x80000000) != 0) { // If prefixed with 1 in MSB, it's an interrupt, not a trap.
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

        if (self.cyclel > cycle) self.cycleh +%= 1;

        self.cyclel = cycle;
        self.pc = pc;

        return 0;
    }
};
