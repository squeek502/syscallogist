const std = @import("std");
const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();
const Reporter = @import("reporting/Reporter.zig");
const Collector = @import("reporting/Collector.zig");
const NtQueryInformationFile = @import("tests/windows/NtQueryInformationFile.zig");
const fsinfo = @import("fsinfo.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var self_exe = try std.fs.openSelfExe(.{});
    defer self_exe.close();

    const fs_info = try fsinfo.getFileystemInfo(allocator, self_exe.handle);
    defer fs_info.deinit(allocator);

    std.debug.print("{s}\n", .{fs_info.fs_name});
    inline for (std.meta.fields(fsinfo.FileSystemFlags)) |field| {
        if (field.type != bool) continue;
        if (@field(fs_info.fs_flags, field.name)) {
            std.debug.print("  {s}\n", .{field.name});
        }
    }
    std.debug.print("  Max component length: {}\n", .{fs_info.max_component_length});
    std.debug.print("\n", .{});

    if (args.len > 1 and std.mem.eql(u8, args[1], "--child")) {
        var reporter = Reporter{ .out = std.io.getStdOut() };

        if (args.len < 2 or !std.mem.startsWith(u8, args[2], "--test=")) {
            return error.MalformedArguments;
        }
        const test_arg = args[2];
        var test_split = std.mem.splitScalar(u8, test_arg, '=');
        _ = test_split.first();
        const test_name = test_split.rest();

        if (!std.mem.eql(u8, test_name, "NtQueryInformationFile")) {
            return error.UnknownTest;
        }

        if (args.len < 3 or !std.mem.startsWith(u8, args[3], "--test-handle=")) {
            return error.MalformedArguments;
        }
        const handle_arg = args[3];
        var handle_split = std.mem.splitScalar(u8, handle_arg, '=');
        _ = handle_split.first();
        const handle_name = handle_split.rest();

        const test_handle = std.meta.stringToEnum(TestHandle, handle_name) orelse {
            return error.UnknownTestHandle;
        };

        const full_name = try std.fmt.allocPrint(allocator, "{s}: {s}", .{ test_name, handle_name });
        defer allocator.free(full_name);

        try reporter.begin(full_name);

        const use_stdin = switch (test_handle) {
            .stdin_nul, .stdin_pipe, .stdin_close => true,
            else => false,
        };
        const handle = if (use_stdin) std.io.getStdIn().handle else self_exe.handle;
        try NtQueryInformationFile.run(handle, allocator, &reporter);

        try reporter.end();
    } else {
        if (!std.process.can_spawn) {
            @compileError("can't spawn child processes on the target system");
        }

        const self_exe_path = try std.fs.selfExePathAlloc(allocator);
        defer allocator.free(self_exe_path);

        var argv = std.ArrayList([]const u8).init(allocator);
        defer argv.deinit();
        try argv.append(self_exe_path);
        try argv.append("--child");

        for (std.enums.values(TestHandle)) |test_handle| {
            argv.shrinkRetainingCapacity(2);

            try argv.append("--test=NtQueryInformationFile");

            var test_handle_buf: [64]u8 = undefined;
            const test_handle_arg = try std.fmt.bufPrint(&test_handle_buf, "--test-handle={s}", .{@tagName(test_handle)});
            try argv.append(test_handle_arg);

            try spawnTest(allocator, argv.items, test_handle);
        }
    }
}

const TestHandle = enum {
    stdin_nul,
    stdin_pipe,
    stdin_close,
    self_exe,
};

fn spawnTest(
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    test_handle: TestHandle,
) !void {
    var child = std.ChildProcess.init(argv, allocator);
    child.stdin_behavior = switch (test_handle) {
        .stdin_nul => .Ignore,
        .stdin_pipe => .Pipe,
        .stdin_close => .Close,
        else => .Ignore,
    };
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    var collector = Collector.init(allocator, child.stdout.?);
    defer collector.deinit();

    var indent: usize = 0;
    const spaces = 2;

    poll: while (true) {
        const header = collector.header() catch |err| switch (err) {
            error.EndOfStream => break :poll,
            else => |e| return e,
        };
        switch (header.tag) {
            .begin_section => {
                const name_header = collector.dataHeader() catch |err| switch (err) {
                    error.EndOfStream => break :poll,
                    else => |e| return e,
                };
                const name_bytes = collector.peekBytes(name_header.len) catch |err| switch (err) {
                    error.EndOfStream => break :poll,
                    else => |e| return e,
                };
                std.io.getStdErr().writer().writeByteNTimes(' ', indent * spaces) catch {};
                std.debug.print("{s}\n", .{name_bytes});
                indent += 1;

                try collector.discardBytes(name_header.len);
            },
            .end_section => {
                indent -= 1;
            },
            .ntstatus => {
                const data_header = collector.dataHeader() catch |err| switch (err) {
                    error.EndOfStream => break :poll,
                    else => |e| return e,
                };
                std.debug.assert(data_header.len == 4);
                const data_bytes = collector.peekBytes(data_header.len) catch |err| switch (err) {
                    error.EndOfStream => break :poll,
                    else => |e| return e,
                };
                const as_int = std.mem.readVarInt(u32, data_bytes, native_endian);
                const as_status: std.os.windows.NTSTATUS = @enumFromInt(as_int);

                std.io.getStdErr().writer().writeByteNTimes(' ', indent * spaces) catch {};
                std.debug.print("NTSTATUS: {s}\n", .{@tagName(as_status)});

                try collector.discardBytes(data_header.len);
            },
            .field => {
                {
                    const name_header = collector.dataHeader() catch |err| switch (err) {
                        error.EndOfStream => break :poll,
                        else => |e| return e,
                    };
                    const name_bytes = collector.peekBytes(name_header.len) catch |err| switch (err) {
                        error.EndOfStream => break :poll,
                        else => |e| return e,
                    };

                    std.io.getStdErr().writer().writeByteNTimes(' ', indent * spaces) catch {};
                    std.debug.print("{s}: ", .{name_bytes});

                    try collector.discardBytes(name_header.len);
                }
                {
                    const data_header = collector.dataHeader() catch |err| switch (err) {
                        error.EndOfStream => break :poll,
                        else => |e| return e,
                    };
                    const data_bytes = collector.peekBytes(data_header.len) catch |err| switch (err) {
                        error.EndOfStream => break :poll,
                        else => |e| return e,
                    };

                    switch (data_header.type) {
                        .str => std.debug.print("{s}\n", .{data_bytes}),
                        .wstr => {
                            const wstr = @as([*]const u16, @ptrCast(@alignCast(data_bytes.ptr)))[0 .. data_header.len / 2];
                            std.debug.print("{s}\n", .{std.unicode.fmtUtf16Le(wstr)});
                        },
                        .uint => switch (data_bytes.len) {
                            1 => std.debug.print("{}\n", .{data_bytes[0]}),
                            4 => std.debug.print("{}\n", .{std.mem.readVarInt(u32, data_bytes, native_endian)}),
                            8 => std.debug.print("{}\n", .{std.mem.readVarInt(u64, data_bytes, native_endian)}),
                            else => @panic("TODO"),
                        },
                        .int => switch (data_bytes.len) {
                            1 => std.debug.print("{}\n", .{@as(i8, @bitCast(data_bytes[0]))}),
                            4 => std.debug.print("{}\n", .{std.mem.readVarInt(i32, data_bytes, native_endian)}),
                            8 => std.debug.print("{}\n", .{std.mem.readVarInt(i64, data_bytes, native_endian)}),
                            else => @panic("TODO"),
                        },
                    }

                    try collector.discardBytes(data_header.len);
                }
            },
        }
    }

    // Just in case there's an error/panic
    const stderr_reader = child.stderr.?.reader();
    const stderr = try stderr_reader.readAllAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(stderr);

    const term = try child.wait();

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                std.debug.print("failed with stderr:\n{s}", .{stderr});
                return std.debug.print("exited with code {d}", .{code});
            }
        },
        else => {
            std.debug.print("failed with stderr:\n{s}", .{stderr});
            return std.debug.print("terminated unexpectedly", .{});
        },
    }
}
