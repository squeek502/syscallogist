const std = @import("std");
const structs = @import("structs.zig");

out: std.fs.File,

const Reporter = @This();

pub fn begin(self: *Reporter, name: []const u8) !void {
    const header = structs.Header{ .tag = .begin_section };
    try self.raw(std.mem.asBytes(&header));
    try self.data(.str, name);
}

pub fn end(self: *Reporter) !void {
    const header = structs.Header{ .tag = .end_section };
    try self.raw(std.mem.asBytes(&header));
}

pub fn ntStatus(self: *Reporter, status: std.os.windows.NTSTATUS) !void {
    const header = structs.Header{ .tag = .ntstatus };
    try self.raw(std.mem.asBytes(&header));
    const status_int = @intFromEnum(status);
    try self.data(.uint, std.mem.asBytes(&status_int));
}

pub fn wstr(self: *Reporter, name: []const u8, val: []const u16) !void {
    const header = structs.Header{ .tag = .field };
    try self.raw(std.mem.asBytes(&header));
    try self.data(.str, name);
    try self.data(.wstr, std.mem.sliceAsBytes(val));
}

pub fn int(self: *Reporter, comptime T: type, name: []const u8, val: T) !void {
    const header = structs.Header{ .tag = .field };
    try self.raw(std.mem.asBytes(&header));
    try self.data(.str, name);
    try self.data(switch (@typeInfo(T).Int.signedness) {
        .unsigned => .uint,
        .signed => .int,
    }, std.mem.asBytes(&val));
}

pub fn data(self: *Reporter, data_type: structs.DataType, bytes: []const u8) !void {
    if (bytes.len > std.math.maxInt(u32)) return error.DataTooLong;
    const header = structs.DataHeader{
        .type = data_type,
        .len = @intCast(bytes.len),
    };
    try self.raw(std.mem.asBytes(&header));
    try self.raw(bytes);
    const num_padding_bytes: u2 = @intCast((4 -% bytes.len) % 4);
    const padding_bytes = [_]u8{0} ** 3;
    if (num_padding_bytes > 0) try self.raw(padding_bytes[0..num_padding_bytes]);
}

pub fn raw(self: *Reporter, bytes: []const u8) !void {
    try self.out.writeAll(bytes);
}
