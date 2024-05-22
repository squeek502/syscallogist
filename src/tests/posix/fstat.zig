const Reporter = @import("../../reporting/Reporter.zig");
const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;

pub const enabled = builtin.os.tag != .windows;

pub fn run(handle: std.fs.File.Handle, allocator: std.mem.Allocator, reporter: *Reporter) !void {
    _ = allocator;

    var stat = std.mem.zeroes(posix.Stat);
    const rc = posix.errno(posix.system.fstat(handle, &stat));
    try reporter.errno(rc);

    switch (rc) {
        .SUCCESS => {},
        else => return,
    }

    try reporter.int(posix.dev_t, "dev", stat.dev);
    try reporter.int(posix.ino_t, "ino", stat.ino);
    try reporter.int(usize, "nlink", stat.nlink);
    try reporter.int(u32, "mode", stat.mode);
    try reporter.int(posix.uid_t, "uid", stat.uid);
    try reporter.int(posix.gid_t, "gid", stat.gid);
    try reporter.int(posix.dev_t, "rdev", stat.rdev);
    try reporter.int(posix.off_t, "size", stat.size);
    try reporter.int(isize, "blksize", stat.blksize);
    try reporter.int(i64, "blocks", stat.blocks);
    try reporter.begin("atim");
    try reporter.int(isize, "tv_sec", stat.atim.tv_sec);
    try reporter.int(isize, "tv_nsec", stat.atim.tv_nsec);
    try reporter.end();
    try reporter.begin("mtim");
    try reporter.int(isize, "tv_sec", stat.mtim.tv_sec);
    try reporter.int(isize, "tv_nsec", stat.mtim.tv_nsec);
    try reporter.end();
    try reporter.begin("ctim");
    try reporter.int(isize, "tv_sec", stat.ctim.tv_sec);
    try reporter.int(isize, "tv_nsec", stat.ctim.tv_nsec);
    try reporter.end();
}
