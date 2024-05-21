const std = @import("std");
const structs = @import("structs.zig");

poller: std.io.Poller(StreamEnum),

const StreamEnum = enum { stdout };

pub fn init(allocator: std.mem.Allocator, stdout: std.fs.File) Collector {
    return .{
        .poller = std.io.poll(allocator, StreamEnum, .{
            .stdout = stdout,
        }),
    };
}

pub fn deinit(self: *Collector) void {
    self.poller.deinit();
}

const Collector = @This();

pub fn header(self: *Collector) !structs.Header {
    const fifo = self.poller.fifo(.stdout);
    while (fifo.readableLength() < @sizeOf(structs.Header)) {
        if (!(try self.poller.poll())) return error.EndOfStream;
    }
    return fifo.reader().readStruct(structs.Header) catch unreachable;
}

pub fn dataHeader(self: *Collector) !structs.DataHeader {
    const fifo = self.poller.fifo(.stdout);
    while (fifo.readableLength() < @sizeOf(structs.DataHeader)) {
        if (!(try self.poller.poll())) return error.EndOfStream;
    }
    return fifo.reader().readStruct(structs.DataHeader) catch unreachable;
}

pub fn peekBytes(self: *Collector, len: u32) ![]const u8 {
    const fifo = self.poller.fifo(.stdout);
    while (fifo.readableLength() < len) {
        if (!(try self.poller.poll())) return error.EndOfStream;
    }
    return fifo.readableSliceOfLen(len);
}

pub fn discardBytes(self: *Collector, data_len: u32) !void {
    const num_padding_bytes: u2 = @intCast((4 -% data_len) % 4);
    const total_bytes = data_len + num_padding_bytes;
    const fifo = self.poller.fifo(.stdout);
    while (fifo.readableLength() < total_bytes) {
        if (!(try self.poller.poll())) return error.EndOfStream;
    }
    self.discardExactBytes(total_bytes);
}

fn discardExactBytes(self: *Collector, len: u32) void {
    const fifo = self.poller.fifo(.stdout);
    std.debug.assert(fifo.readableLength() >= len);
    fifo.discard(len);
}
