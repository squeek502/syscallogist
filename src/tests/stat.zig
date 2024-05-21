const std = @import("std");
const windows = std.os.windows;

pub fn run(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype) !void {
    _ = allocator;
    _ = stdout;
    _ = stderr;

    const stdin = std.io.getStdIn();

    // var io_status_block: windows.IO_STATUS_BLOCK = undefined;
    // var info: windows.FILE_STAT_INFORMATION = undefined;
    // const rc = windows.ntdll.NtQueryInformationFile(stdin.handle, &io_status_block, &info, @sizeOf(windows.FILE_STAT_INFORMATION), .FileStatInformation);
    // switch (rc) {
    //     .SUCCESS => {},
    //     // Buffer overflow here indicates that there is more information available than was able to be stored in the buffer
    //     // size provided. This is treated as success because the type of variable-length information that this would be relevant for
    //     // (name, volume name, etc) we don't care about.
    //     .BUFFER_OVERFLOW => {},
    //     .INVALID_PARAMETER => unreachable,
    //     .ACCESS_DENIED => return error.AccessDenied,
    //     else => return windows.unexpectedStatus(rc),
    // }
    // std.debug.print("{}\n", .{info});

    var c_stat: std.c.Stat = undefined;
    std.c.fstat(stdin.handle, &c_stat);
    std.debug.print("{}\n", .{c_stat});
}
