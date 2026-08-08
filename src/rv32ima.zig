const std = @import("std");

pub const RAM_IMAGE_OFFSET: u32 = 0x80000000;

const MSTATUS_WRITE_MASK: u32 = 0xFFA3FEDD;
const MSTATUS_MPP_MASK: u32 = 0x1800;
const MIP_MIE_WRITE_MASK: u32 = 0x2888;

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

const IR = packed struct(u32) {
    opcode: u7,
    rd: u5,
    funct3: u3,
    rs1: u5,
    rs2: u5,
    funct7: u7,

    const Self = @This();

    fn i_imm(self: *const Self) u32 {
        return @as(u32, @bitCast(self.*)) >> 20;
    }
    fn s_imm(self: *const Self) u32 {
        const ir: u32 = @bitCast(self.*);
        return ((ir >> 7) & 0x1F) | ((ir & 0xFE000000) >> 20);
    }
    fn b_imm(self: *const Self) u32 {
        const ir: u32 = @bitCast(self.*);
        return ((ir & 0xF00) >> 7) | ((ir & 0x7E000000) >> 20) | ((ir & 0x80) << 4) | ((ir >> 31) << 12);
    }
    fn u_imm(self: *const Self) u32 {
        return @as(u32, @bitCast(self.*)) & 0xFFFFF000;
    }
    fn j_imm(self: *const Self) u32 {
        const ir: u32 = @bitCast(self.*);
        return ((ir & 0x80000000) >> 11) | ((ir & 0x7fe00000) >> 20) | ((ir & 0x00100000) >> 9) | ((ir & 0x000ff000));
    }
};

const Opcodes = struct {
    const OP_IMMEDIATE: u32 = 0x13;
    const OP_or_MULDIV: u32 = 0x33;
    const FENCE_I: u32 = 0x0F;
    const CSR: u32 = 0x73;
    const AMO: u32 = 0x2F;
};

const OP = struct {
    const ADD_or_SUB: u32 = 0;
    const SLT: u32 = 2;
    const SLTU: u32 = 3;
    const XOR: u32 = 4;
    const OR: u32 = 6;
    const AND: u32 = 7;
    const SLL: u32 = 1;
    const SRL_or_SRA: u32 = 5;
};

const MULDIV = struct {
    const MUL: u32 = 0;
    const MULH: u32 = 1;
    const MULHSU: u32 = 2;
    const MULHU: u32 = 3;
    const DIV: u32 = 4;
    const DIVU: u32 = 5;
    const REM: u32 = 6;
    const REMU: u32 = 7;
};

const AMO = struct {
    // riscv unprivileged spec: 13.2. "Zalrsc" Extension for Load-Reserved/Store-Conditional Instructions
    const LR: u32 = 2;
    const SC: u32 = 3;

    // riscv unprivileged spec: 13.4. "Zaamo" Extension for Atomic Memory Operations
    const SWAP: u32 = 1;
    const ADD: u32 = 0;
    const XOR: u32 = 4;
    const AND: u32 = 12;
    const OR: u32 = 8;
    const MIN: u32 = 16;
    const MAX: u32 = 20;
    const MINU: u32 = 24;
    const MAXU: u32 = 28;
};

pub const Traps = enum(u32) {
    // riscv privileged spec: 21.6.1. Trap Cause Codes
    instruction_address_misaligned = 0,
    instruction_access_fault,
    illegal_instruction,
    breakpoint,
    load_address_misaligned, // Not used.
    load_access_fault,
    store_address_misaligned, // Not used.
    store_access_fault,
    environment_call_from_U_mode,
    environment_call_from_M_mode = 11,

    //riscv privileged spec: 21.6.1. Trap Cause Codes
    machine_timer_interrupt = 0x80000007,
};

const Result = struct {
    val: u32 = 0,
    trap: ?Traps = null,
};

pub const Handlers = struct {
    ptr: *anyopaque,
    vtable: struct {
        post_exec: *const fn (ptr: *anyopaque, core: *NanoRV32IMA, pc: u32, ir: u32, trap: ?Traps) void,
        control_store: *const fn (ptr: *anyopaque, core: *NanoRV32IMA, addy: u32, val: u32) u32,
        control_load: *const fn (ptr: *anyopaque, core: *NanoRV32IMA, addy: u32) u32,
        other_csr_write: *const fn (ptr: *anyopaque, core: *NanoRV32IMA, ptr: []u8, csrno: u16, value: u32) void,
        other_csr_read: *const fn (ptr: *anyopaque, core: *NanoRV32IMA, ptr: []u8, csrno: u16) i32,
    },

    const Self = @This();

    pub fn post_exec(self: *Self, core: *NanoRV32IMA, pc: u32, ir: u32, trap: ?Traps) void {
        self.vtable.post_exec(self.ptr, core, pc, ir, trap);
    }

    pub fn control_store(self: *Self, core: *NanoRV32IMA, addy: u32, val: u32) u32 {
        return self.vtable.control_store(self.ptr, core, addy, val);
    }

    pub fn control_load(self: *Self, core: *NanoRV32IMA, addy: u32) u32 {
        return self.vtable.control_load(self.ptr, core, addy);
    }

    pub fn other_csr_write(self: *Self, core: *NanoRV32IMA, ptr: []u8, csrno: u16, value: u32) void {
        self.vtable.other_csr_write(self.ptr, core, ptr, csrno, value);
    }

    pub fn other_csr_read(self: *Self, core: *NanoRV32IMA, ptr: []u8, csrno: u16) i32 {
        return self.vtable.other_csr_read(self.ptr, core, ptr, csrno);
    }
};

pub const Mode = enum {
    user,
    machine,
};

pub const NanoRV32IMA = struct {
    regs: [32]u32 = std.mem.zeroes([32]u32),
    f_regs: [32]f32 = std.mem.zeroes([32]f32),

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

    // Float
    fcsr: u32 = 0,

    mode: Mode = .machine,
    wfi: bool = false,
    reserved_addr: u32 = 0xFFFFFFFF,

    handlers: Handlers,
    ram: []u8,

    const Self = @This();

    pub fn init(handlers: Handlers, ram: []u8) Self {
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
            self.wfi = false;
            self.mip |= @as(u32, 1 << 7);
        } else {
            self.mip &= ~@as(u32, 1 << 7);
        }

        if (self.wfi) return 1;

        var trap: ?Traps = null;
        var rval: u32 = 0;
        var cycle: u32 = self.cyclel;

        defer {
            if (trap) |trap_val| {
                const trap_code: u32 = @intFromEnum(trap_val);

                self.mcause = trap_code;
                self.mtval = if ((trap_code > 5) and (trap_code <= 8)) rval else self.pc;
                if (trap_val == .illegal_instruction or trap_val == .instruction_address_misaligned) { // temp fix. need to make it all the vals are set to rval.
                    self.mtval = rval;
                }

                if ((trap_code & 0x80000000) != 0) { // If prefixed with 1 in MSB, it's an interrupt, not a trap.
                    self.mtval = 0;
                    self.pc +%= 4;
                }

                self.mepc = self.pc;
                self.mstatus = ((self.mstatus & 8) << 4) | @as(u32, if (self.mode == .machine) 0x1800 else 0);
                self.pc = self.mtvec -% 4;
                self.mode = .machine;
                trap = null;
                self.pc +%= 4;
            }

            if (self.cyclel > cycle) self.cycleh +%= 1;

            self.cyclel = cycle;
        }

        if ((self.mip & (1 << 7)) != 0 and (self.mie & (1 << 7)) != 0 and (self.mstatus & 0x8) != 0) {
            trap = .machine_timer_interrupt;
            self.pc -%= 4;

            return 0;
        }

        var icount: u32 = 0;
        while (icount < count) : (icount += 1) {
            rval = 0;
            cycle +%= 1;

            const ofs_pc: u32 = self.pc -% RAM_IMAGE_OFFSET;
            if (ofs_pc >= self.ram.len) {
                trap = .instruction_access_fault;
                break;
            }

            if ((ofs_pc & 3) != 0) {
                trap = .instruction_address_misaligned;
                rval = self.pc;
                break;
            }

            const ir: IR = @bitCast(load(u32, ofs_pc, self.ram));
            var new_pc = self.pc;

            var rd = ir.rd;

            switch (ir.opcode) {
                0x37 => rval = ir.u_imm(), // LUI (0b0110111)
                0x17 => rval = self.pc +% ir.u_imm(), // AUIPC (0b0010111)
                0x6F => { // JAL (0b1101111)
                    var reladdy: u32 = ir.j_imm();
                    if ((reladdy & 0x100000) != 0) reladdy |= 0xFFE00000;

                    new_pc = self.pc +% reladdy -% 4;
                    rval = self.pc +% 4;
                },
                0x67 => { // JALR (0b1100111)
                    const imm: u32 = ir.i_imm();
                    const imm_se: u32 = imm | @as(u32, if ((imm & 0x800) != 0) 0xFFFFF000 else 0);

                    new_pc = ((self.regs[ir.rs1] +% imm_se) & ~@as(u32, 1)) -% 4;
                    rval = self.pc +% 4;
                },
                0x63 => { // Branch (0b1100011)
                    rd = 0; // imm here.

                    var immm4: u32 = ir.b_imm();
                    if ((immm4 & 0x1000) != 0) immm4 |= 0xFFFFE000;

                    const rs1 = self.regs[ir.rs1];
                    const rs2 = self.regs[ir.rs2];
                    immm4 = (self.pc +% immm4) -% 4;

                    switch (ir.funct3) {
                        0 => {
                            if (rs1 == rs2) new_pc = immm4;
                        },
                        1 => {
                            if (rs1 != rs2) new_pc = immm4;
                        },
                        4 => {
                            if (@as(i32, @bitCast(rs1)) < @as(i32, @bitCast(rs2))) new_pc = immm4;
                        },
                        5 => {
                            if (@as(i32, @bitCast(rs1)) >= @as(i32, @bitCast(rs2))) new_pc = immm4;
                        },
                        6 => {
                            if (rs1 < rs2) new_pc = immm4;
                        },
                        7 => {
                            if (rs1 >= rs2) new_pc = immm4;
                        },
                        else => {
                            trap = .illegal_instruction;
                            rval = @bitCast(ir);
                        },
                    }
                },
                0x03 => { // Load (0b0000011)
                    const rs1: u32 = self.regs[ir.rs1];
                    const imm: u32 = ir.i_imm();
                    const imm_se: u32 = imm | @as(u32, if ((imm & 0x800) != 0) 0xFFFFF000 else 0);

                    var rsval: u32 = rs1 +% imm_se;

                    rsval -%= RAM_IMAGE_OFFSET;
                    if (rsval >= (self.ram.len - 3)) {
                        rsval +%= RAM_IMAGE_OFFSET;
                        if (mmio_range(rsval)) {
                            rval = self.handlers.control_load(self, rsval);
                        } else {
                            trap = .load_access_fault;
                            rval = rsval;
                        }
                    } else {
                        switch (ir.funct3) {
                            0 => rval = load_signed(i8, rsval, self.ram),
                            1 => rval = load_signed(i16, rsval, self.ram),
                            2 => rval = load(u32, rsval, self.ram),
                            4 => rval = load(u8, rsval, self.ram),
                            5 => rval = load(u16, rsval, self.ram),
                            else => {
                                trap = .illegal_instruction;
                                rval = @bitCast(ir);
                            },
                        }
                    }
                },
                0x23 => { // Store 0b0100011
                    const rs1: u32 = self.regs[ir.rs1];
                    const rs2: u32 = self.regs[ir.rs2];

                    var addy: u32 = ir.s_imm();
                    if ((addy & 0x800) != 0) addy |= 0xFFFFF000;

                    addy +%= rs1;
                    rd = 0;

                    if (@import("builtin").is_test and (addy == 0x80001000 or addy == 0x80002000)) {
                        _ = self.handlers.control_store(self, addy, rs2);
                    }

                    addy -%= RAM_IMAGE_OFFSET;

                    if (addy >= (self.ram.len - 3)) {
                        addy +%= RAM_IMAGE_OFFSET;
                        if (mmio_range(addy)) {
                            if (self.handlers.control_store(self, addy, rs2) != 0) return @bitCast(rs2);
                        } else {
                            trap = .store_access_fault;
                            rval = addy;
                        }
                    } else {
                        switch (ir.funct3) {
                            0 => store(u8, addy, rs2, self.ram),
                            1 => store(u16, addy, rs2, self.ram),
                            2 => store(u32, addy, rs2, self.ram),
                            else => {
                                trap = .illegal_instruction;
                                rval = @bitCast(ir);
                            },
                        }
                    }
                },
                Opcodes.OP_IMMEDIATE, Opcodes.OP_or_MULDIV => {
                    const is_reg: bool = (ir.opcode == Opcodes.OP_or_MULDIV);

                    if (is_reg and ir.funct7 == 1) {
                        const r = self.rv32M_muldiv(ir);
                        rval = r.val;
                        trap = r.trap;
                    } else {
                        var imm: u32 = ir.i_imm();
                        imm |= @as(u32, if ((imm & 0x800) != 0) 0xFFFFF000 else 0);

                        const rs1: u32 = self.regs[ir.rs1];

                        const rs2: u32 = if (is_reg) self.regs[imm & 0x1F] else imm;
                        const shift_amt: u5 = @intCast(rs2 & 0x1F);
                        const rs2_rest = rs2 >> 5;

                        const ir_int: u32 = @bitCast(ir);

                        rval = switch (ir.funct3) {
                            OP.ADD_or_SUB => if ((is_reg) and ((ir_int & @as(u32, 0x40000000)) != 0)) rs1 -% rs2 else rs1 +% rs2,
                            OP.SLT => @intFromBool(@as(i32, @bitCast(rs1)) < @as(i32, @bitCast(rs2))),
                            OP.SLTU => @intFromBool(rs1 < rs2),
                            OP.XOR => rs1 ^ rs2,
                            OP.OR => rs1 | rs2,
                            OP.AND => rs1 & rs2,
                            OP.SLL => blk: {
                                if (!is_reg and rs2_rest != 0) {
                                    trap = .illegal_instruction;
                                    rval = @bitCast(ir);
                                    break :blk rval;
                                }

                                break :blk rs1 << shift_amt;
                            },
                            OP.SRL_or_SRA => blk: {
                                if (!is_reg and rs2_rest != 0 and rs2_rest != 0x20) {
                                    trap = .illegal_instruction;
                                    rval = @bitCast(ir);
                                    break :blk rval;
                                }

                                break :blk if ((ir_int & 0x40000000) != 0) @bitCast(@as(i32, @bitCast(rs1)) >> shift_amt) else rs1 >> shift_amt;
                            },
                        };
                    }
                },
                Opcodes.FENCE_I => rd = 0, // TODO: I'll check later.
                Opcodes.CSR => { // Zicsr  (0b1110011)
                    const csrno: u32 = ir.i_imm();
                    const microop: u32 = ir.funct3;

                    if (microop != 0) {
                        const r = self.rv32Zicsr(ir, cycle);
                        rval = r.val;
                        trap = r.trap;
                    } else { // "SYSTEM" 0b000
                        rd = 0;
                        if ((csrno & 0xFF) == 2) { // MRET
                            const startmstatus: u32 = self.mstatus;
                            self.mstatus = ((startmstatus & 0x80) >> 4) | @as(u32, if (self.mode == .machine) 0x1800 else 0) | 0x80;
                            self.mode = if (((startmstatus >> 11) & 3) != 0) .machine else .user;
                            new_pc = self.mepc -% 4;
                        } else {
                            switch (csrno) {
                                0 => trap = if (self.mode == .machine) .environment_call_from_M_mode else .environment_call_from_U_mode,
                                1 => trap = .breakpoint,
                                261 => {
                                    self.mstatus |= 8;
                                    self.wfi = true;
                                    if (self.cyclel > cycle) {
                                        self.cycleh +%= 1;
                                    }

                                    self.cyclel = cycle;
                                    self.handlers.post_exec(self, self.pc, @bitCast(ir), trap);

                                    new_pc = self.pc +% 4;

                                    return 1;
                                },
                                else => {
                                    trap = .illegal_instruction;
                                    rval = @bitCast(ir);
                                },
                            }
                        }
                    }
                },
                Opcodes.AMO => { // RV32A (0b00101111)
                    const r = self.rv32A_atomic(ir);
                    rval = r.val;
                    trap = r.trap;
                },
                // RV32F
                0x07 => { // FLW
                    rd = 0;
                    const rs1 = self.regs[ir.rs1];
                    const addr = rs1 +% ir.i_imm() -% RAM_IMAGE_OFFSET;

                    rval = switch (ir.funct3) {
                        2 => load(u32, addr, self.ram),
                        else => unreachable, // TODO: only for now.
                    };

                    self.f_regs[ir.rd] = @bitCast(rval);
                },
                0x27 => { // FSW
                    rd = 0;
                    const rs1: u32 = self.regs[ir.rs1];
                    const f_rs2: f32 = self.f_regs[ir.rs2];

                    var addy: u32 = ir.s_imm();
                    if ((addy & 0x800) != 0) addy |= 0xFFFFF000;

                    addy +%= rs1;
                    addy -%= RAM_IMAGE_OFFSET;

                    switch (ir.funct3) {
                        2 => store(u32, addy, @bitCast(f_rs2), self.ram),
                        else => unreachable, // TODO: only for now.
                    }
                },
                0x53 => {
                    rd = 0;
                    var write_to_int: bool = false;

                    const rs1 = self.regs[ir.rs1];
                    var f_rs1 = self.f_regs[ir.rs1];
                    var f_rs2 = self.f_regs[ir.rs2];

                    var rvalf: f32 = 0;

                    switch (ir.funct7) {
                        // RV32F
                        0x14 => {
                            if (std.math.isNan(f_rs1) and (@as(u32, @bitCast(f_rs1)) & (1 << 22)) == 0) {
                                self.fcsr |= 0x10;
                                f_rs1 = std.math.nan(f32);
                            }
                            if (std.math.isNan(f_rs2) and (@as(u32, @bitCast(f_rs2)) & (1 << 22)) == 0) {
                                self.fcsr |= 0x10;
                                f_rs2 = std.math.nan(f32);
                            }

                            if (std.math.isNan(f_rs1) and std.math.isNan(f_rs2)) {
                                rvalf = std.math.nan(f32);
                            } else {
                                // https://codeberg.org/ziglang/zig/issues/36420
                                // these if statements are sort of useless.
                                rvalf = switch (ir.funct3) {
                                    0 => if ((f_rs1 == -0e0 and f_rs2 == 0e0) or (f_rs2 == -0e0 and f_rs1 == 0e0)) -0e0 else @min(f_rs1, f_rs2),
                                    1 => if ((f_rs1 == -0e0 and f_rs2 == 0e0) or (f_rs2 == -0e0 and f_rs1 == 0e0)) 0e0 else @max(f_rs1, f_rs2),
                                    else => {
                                        trap = .illegal_instruction;
                                        rval = @bitCast(ir);
                                        self.handlers.post_exec(self, self.pc, @bitCast(ir), trap);

                                        break;
                                    },
                                };
                            }
                        },
                        0x10 => { // FSGNJ
                            switch (ir.funct3) {
                                0 => rvalf = @bitCast(@as(u32, @bitCast(f_rs1)) & 0x7FFFFFFF | (@as(u32, @bitCast(f_rs2)) & (1 << 31))), // FSGNJ.S
                                1 => rvalf = @bitCast(@as(u32, @bitCast(f_rs1)) & 0x7FFFFFFF | ~(@as(u32, @bitCast(f_rs2)) & (1 << 31))), // FSGNJN.S
                                2 => rvalf = @bitCast(@as(u32, @bitCast(f_rs1)) & 0x7FFFFFFF | (@as(u32, @bitCast(f_rs1)) & (1 << 31)) ^ @as(u32, @bitCast(f_rs2)) & (1 << 31)), // FSGNJX.S

                                else => {
                                    trap = .illegal_instruction;
                                    rval = @bitCast(ir);
                                    self.handlers.post_exec(self, self.pc, @bitCast(ir), trap);

                                    break;
                                },
                            }
                        },
                        0x70 => {
                            switch (ir.funct3) {
                                0 => { // FMV.X.W
                                    rvalf = f_rs1;
                                    write_to_int = true;
                                },
                                // 1 => { // FCLASS.S

                                // },
                                else => {
                                    trap = .illegal_instruction;
                                    rval = @bitCast(ir);
                                    self.handlers.post_exec(self, self.pc, @bitCast(ir), trap);

                                    break;
                                },
                            }
                        },
                        0x78 => { // FMV.W.X
                            rvalf = @bitCast(rs1);
                        },
                        else => {
                            trap = .illegal_instruction;
                            rval = @bitCast(ir);
                            self.handlers.post_exec(self, self.pc, @bitCast(ir), trap);

                            break;
                        },
                    }

                    if (write_to_int) {
                        self.regs[ir.rd] = @bitCast(rvalf);
                    } else {
                        self.f_regs[ir.rd] = rvalf;
                    }
                },
                else => {
                    trap = .illegal_instruction;
                    rval = @bitCast(ir);
                },
            }

            if ((new_pc & 3) != 0) {
                trap = .instruction_address_misaligned;
                rval = new_pc +% 4;
            }

            if (trap != null) {
                self.handlers.post_exec(self, self.pc, @bitCast(ir), trap);
                break;
            }

            if (rd != 0) {
                self.regs[rd] = rval;
            }

            self.handlers.post_exec(self, self.pc, @bitCast(ir), trap);
            self.pc = new_pc +% 4;
        }

        return 0;
    }

    fn rv32Zicsr(self: *Self, ir: IR, cycle: u32) Result {
        // TODO: arg cycle is a temp fix.

        const rs1imm: u32 = ir.rs1;
        const rs1: u32 = self.regs[rs1imm];

        const csrno = ir.i_imm();

        const rval: u32 = switch (csrno) {
            0x001 => self.fcsr & 0x1F,
            0x002 => (self.fcsr >> 5),
            0x003 => self.fcsr,
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

        const writeval = switch (ir.funct3) {
            1 => rs1, //CSRRW
            2 => rval | rs1, //CSRRS
            3 => rval & ~rs1, //CSRRC
            5 => rs1imm, //CSRRWI
            6 => rval | rs1imm, //CSRRSI
            7 => rval & ~rs1imm, //CSRRCI
            else => return .{ .val = @bitCast(ir), .trap = .illegal_instruction },
        };

        switch (csrno) {
            0x001 => self.fcsr = (self.fcsr & 0xE0) | writeval & 0x1F,
            0x002 => self.fcsr = (self.fcsr & 0x1F) | ((writeval & 0x7) << 5),
            0x003 => self.fcsr = (writeval & 0xFF),
            0x340 => self.mscratch = writeval,
            0x305 => self.mtvec = writeval,
            0x304 => self.mie = (writeval & MIP_MIE_WRITE_MASK),
            0x344 => self.mip = (writeval & MIP_MIE_WRITE_MASK),
            0x341 => self.mepc = writeval,
            0x300 => {
                const val = writeval & MSTATUS_WRITE_MASK;
                self.mstatus = switch (val & MSTATUS_MPP_MASK) {
                    0, 3 => val,
                    else => (val & ~MSTATUS_MPP_MASK) | (rval & MSTATUS_MPP_MASK),
                };
            },
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

        return .{ .val = rval };
    }

    fn rv32M_muldiv(self: *Self, ir: IR) Result {
        const rs1: u32 = self.regs[ir.rs1];
        const rs2: u32 = self.regs[ir.rs2];

        var rval: u32 = 0;
        switch (ir.funct3) {
            MULDIV.MUL => rval = rs1 *% rs2,
            MULDIV.MULH => rval = @truncate(@as(u64, @bitCast(@as(i64, @as(i32, @bitCast(rs1))) * @as(i64, @as(i32, @bitCast(rs2))))) >> 32),
            MULDIV.MULHSU => rval = @truncate(@as(u64, @bitCast(@as(i64, @as(i32, @bitCast(rs1))))) *% @as(u64, rs2) >> 32),
            MULDIV.MULHU => rval = @truncate((@as(u64, rs1) *% @as(u64, rs2)) >> 32),
            MULDIV.DIV => if (rs2 == 0) {
                rval = @bitCast(@as(i32, -1));
            } else {
                if ((@as(i32, @bitCast(rs1)) == std.math.minInt(i32)) and (@as(i32, @bitCast(rs2))) == -1) {
                    rval = rs1;
                } else {
                    rval = @as(u32, @bitCast(@divTrunc(@as(i32, @bitCast(rs1)), @as(i32, @bitCast(rs2)))));
                }
            },
            MULDIV.DIVU => rval = if (rs2 == 0) 0xFFFFFFFF else rs1 / rs2,
            MULDIV.REM => if (rs2 == 0) {
                rval = rs1;
            } else {
                if ((@as(i32, @bitCast(rs1)) == std.math.minInt(i32)) and (@as(i32, @bitCast(rs2))) == -1) {
                    rval = 0;
                } else {
                    rval = @bitCast(@rem(@as(i32, @bitCast(rs1)), @as(i32, @bitCast(rs2))));
                }
            },
            MULDIV.REMU => rval = if (rs2 == 0) rs1 else rs1 % rs2,
        }

        return .{ .val = rval };
    }

    fn rv32A_atomic(self: *Self, ir: IR) Result {
        var rs1: u32 = self.regs[ir.rs1];
        var rs2: u32 = self.regs[ir.rs2];

        rs1 -%= RAM_IMAGE_OFFSET;

        if (rs1 >= (self.ram.len - 3)) {
            return .{
                .val = rs1 +% RAM_IMAGE_OFFSET,
                .trap = .store_access_fault,
            };
        }

        var val = load(u32, rs1, self.ram);
        var dowrite = true;

        // We are ignoring the aquire & release bits.
        // it's fine for single core. but if I ever expand this
        // to multi-core then I have to take care of this.
        switch (ir.funct7 >> 2) {
            AMO.LR => {
                dowrite = false;
                self.reserved_addr = rs1;
            },
            AMO.SC => {
                val = @intFromBool(self.reserved_addr != rs1);
                dowrite = (val == 0);
                self.reserved_addr = 0xFFFFFFFF;
            },
            AMO.SWAP => {},
            AMO.ADD => rs2 +%= val,
            AMO.XOR => rs2 ^= val,
            AMO.AND => rs2 &= val,
            AMO.OR => rs2 |= val,
            AMO.MIN => rs2 = if (@as(i32, @bitCast(rs2)) < @as(i32, @bitCast(val))) rs2 else val,
            AMO.MAX => rs2 = if (@as(i32, @bitCast(rs2)) > @as(i32, @bitCast(val))) rs2 else val,
            AMO.MINU => rs2 = if (rs2 < val) rs2 else val,
            AMO.MAXU => rs2 = if (rs2 > val) rs2 else val,
            else => {
                return .{
                    .val = @bitCast(ir),
                    .trap = .illegal_instruction,
                };
            },
        }

        if (dowrite) store(u32, rs1, rs2, self.ram);

        return .{ .val = val };
    }
};
