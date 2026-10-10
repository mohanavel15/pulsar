const std = @import("std");
const rv32ima = @import("rv32ima.zig");

const TEST_DIR = "riscv-tests-isa";
const EXTENSIONS = [_]*const [1:0]u8{ "i", "m", "a", "f" };
const RAM_SIZE: u32 = 1 * 1024 * 1024;

test "riscv-tests-isa" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;

    for (EXTENSIONS) |ext| {
        const dir = std.Io.Dir.cwd().openDir(io, TEST_DIR ++ "/" ++ ext ++ "/", .{ .iterate = true }) catch unreachable;
        defer dir.close(io);
        var iter = dir.iterate();

        var total_test_count: usize = 0;
        var passed_test_count: usize = 0;

        std.debug.print("==========rv32{s}==========\n", .{ext});

        while (try iter.next(io)) |entry| {
            const path = std.fmt.allocPrint(allocator, TEST_DIR ++ "/{s}/{s}", .{ ext, entry.name }) catch unreachable;
            defer allocator.free(path);

            if (entry.name.len > 4 and std.mem.eql(u8, entry.name[(entry.name.len - 4)..], ".bin")) {
                const result = load_and_run(io, allocator, path);
                total_test_count += 1;

                if (result == .pass) passed_test_count += 1;

                switch (result) {
                    .pass => {},
                    .fail => |code| std.debug.print("[FAIL] {s} - Error: {d}\n", .{ entry.name, code }),
                    .hang => std.debug.print("[HANG] {s}\n", .{entry.name}),
                }
            }
        }

        std.debug.print("{d}/{d} PASSED - {d}/{d} FAILED\n\n", .{
            passed_test_count,
            total_test_count,
            total_test_count - passed_test_count,
            total_test_count,
        });
    }
}

const Result = union(enum) {
    pass,
    fail: u32,
    hang,
};

fn load_and_run(io: std.Io, allocator: std.mem.Allocator, path: []u8) Result {
    const ram_image = allocator.alloc(u8, RAM_SIZE) catch unreachable;
    defer allocator.free(ram_image);

    @memset(ram_image, 0);

    _ = std.Io.Dir.cwd().readFile(io, path, ram_image) catch unreachable;

    var handlers = TestHandler{};

    if (path.len > 18 and std.mem.eql(u8, path[(path.len - 18)..], "rv32ui-p-ld_st.bin")) {
        handlers.to_host_address = 0x80002000;
    }

    var core = rv32ima.Pulsar.init(handlers.handlers(), ram_image);

    for (0..10240) |count| {
        if (handlers.received_output) break;
        _ = core.step(@intCast(count), 1);
    }

    if (!handlers.received_output) return .hang;

    if (handlers.output_value != 1) {
        return .{ .fail = handlers.output_value };
    }

    return .pass;
}

const TestHandler = struct {
    output_value: u32 = 0,
    received_output: bool = false,
    to_host_address: u32 = 0x80001000,

    const Self = @This();

    fn control_store(ptr: *anyopaque, _: *rv32ima.Pulsar, addy: u32, val: u32) u32 {
        var self: *Self = @ptrCast(@alignCast(ptr));

        if (addy == self.to_host_address) {
            self.received_output = true;
            self.output_value = val;
        }

        return 0;
    }

    fn post_exec(_: *anyopaque, _: *rv32ima.Pulsar, _: u32, _: u32, _: ?rv32ima.Traps) void {}
    fn control_load(_: *anyopaque, _: *rv32ima.Pulsar, _: u32) u32 {
        return 0;
    }
    fn other_csr_write(_: *anyopaque, _: *rv32ima.Pulsar, _: []u8, _: u16, _: u32) void {}
    fn other_csr_read(_: *anyopaque, _: *rv32ima.Pulsar, _: []u8, _: u16) i32 {
        return 0;
    }

    fn handlers(self: *Self) rv32ima.Handlers {
        return rv32ima.Handlers{
            .ptr = self,
            .vtable = .{
                .post_exec = Self.post_exec,
                .control_load = Self.control_load,
                .control_store = Self.control_store,
                .other_csr_read = Self.other_csr_read,
                .other_csr_write = Self.other_csr_write,
            },
        };
    }
};
