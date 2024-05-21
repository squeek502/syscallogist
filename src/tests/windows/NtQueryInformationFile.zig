const Reporter = @import("../../reporting/Reporter.zig");
const std = @import("std");
const windows = std.os.windows;

pub fn run(handle: std.fs.File.Handle, allocator: std.mem.Allocator, reporter: *Reporter) !void {
    // TODO: Stack allocate if this is small enough for that
    const buf = try allocator.allocWithOptions(u8, max_buf_size, max_alignment, null);
    defer allocator.free(buf);

    inline for (classes) |class| {
        _ = classToStruct(class) orelse continue;

        try reporter.begin(@tagName(class));
        defer reporter.end() catch {};

        try runClass(class, handle, buf, reporter);
    }
}

fn runClass(comptime class: windows.FILE_INFORMATION_CLASS, handle: std.fs.File.Handle, buf: []align(max_alignment) u8, reporter: *Reporter) !void {
    const T = classToStruct(class) orelse return;

    var io_status_block: windows.IO_STATUS_BLOCK = undefined;
    const rc = windows.ntdll.NtQueryInformationFile(handle, &io_status_block, buf.ptr, @intCast(bufSize(class)), class);
    try reporter.ntStatus(rc);

    switch (rc) {
        .SUCCESS => {},
        else => return,
    }

    const info: *T = @ptrCast(buf.ptr);
    try reportInfo(class, info, reporter);
}

fn reportInfo(comptime class: windows.FILE_INFORMATION_CLASS, info: *const classToStruct(class).?, reporter: *Reporter) !void {
    switch (class) {
        .FileBasicInformation => {
            try reporter.int(windows.LARGE_INTEGER, "CreationTime", info.CreationTime);
            try reporter.int(windows.LARGE_INTEGER, "LastAccessTime", info.LastAccessTime);
            try reporter.int(windows.LARGE_INTEGER, "LastWriteTime", info.LastWriteTime);
            try reporter.int(windows.LARGE_INTEGER, "ChangeTime", info.ChangeTime);
            try reporter.int(windows.ULONG, "FileAttributes", info.FileAttributes);
        },
        .FileStandardInformation => {
            try reporter.int(windows.LARGE_INTEGER, "AllocationSize", info.AllocationSize);
            try reporter.int(windows.LARGE_INTEGER, "EndOfFile", info.EndOfFile);
            try reporter.int(windows.ULONG, "NumberOfLinks", info.NumberOfLinks);
            try reporter.int(windows.BOOLEAN, "DeletePending", info.DeletePending);
            try reporter.int(windows.BOOLEAN, "Directory", info.Directory);
        },
        .FileInternalInformation => {
            try reporter.int(windows.LARGE_INTEGER, "IndexNumber", info.IndexNumber);
        },
        .FileEaInformation => {
            try reporter.int(windows.ULONG, "EaSize", info.EaSize);
        },
        .FileAccessInformation => {
            try reporter.int(windows.ACCESS_MASK, "AccessFlags", info.AccessFlags);
        },
        .FilePositionInformation => {
            try reporter.int(windows.LARGE_INTEGER, "CurrentByteOffset", info.CurrentByteOffset);
        },
        .FileModeInformation => {
            try reporter.int(windows.ULONG, "Mode", info.Mode);
        },
        .FileAlignmentInformation => {
            try reporter.int(windows.ULONG, "AlignmentRequirement", info.AlignmentRequirement);
        },
        .FileNameInformation => {
            try reporter.int(windows.ULONG, "FileNameLength", info.FileNameLength);
            const name = @as([*]const u16, @ptrCast(&info.FileName))[0 .. info.FileNameLength / 2];
            try reporter.wstr("FileName", name);
        },
        .FileAllInformation => {
            try reporter.begin("BasicInformation");
            try reportInfo(.FileBasicInformation, &info.BasicInformation, reporter);
            try reporter.end();
            try reporter.begin("StandardInformation");
            try reportInfo(.FileStandardInformation, &info.StandardInformation, reporter);
            try reporter.end();
            try reporter.begin("InternalInformation");
            try reportInfo(.FileInternalInformation, &info.InternalInformation, reporter);
            try reporter.end();
            try reporter.begin("EaInformation");
            try reportInfo(.FileEaInformation, &info.EaInformation, reporter);
            try reporter.end();
            try reporter.begin("AccessInformation");
            try reportInfo(.FileAccessInformation, &info.AccessInformation, reporter);
            try reporter.end();
            try reporter.begin("PositionInformation");
            try reportInfo(.FilePositionInformation, &info.PositionInformation, reporter);
            try reporter.end();
            try reporter.begin("ModeInformation");
            try reportInfo(.FileModeInformation, &info.ModeInformation, reporter);
            try reporter.end();
            try reporter.begin("AlignmentInformation");
            try reportInfo(.FileAlignmentInformation, &info.AlignmentInformation, reporter);
            try reporter.end();
            try reporter.begin("NameInformation");
            try reportInfo(.FileNameInformation, &info.NameInformation, reporter);
            try reporter.end();
        },
        .FileStatInformation => {
            try reporter.int(windows.LARGE_INTEGER, "FileId", info.FileId);
            try reporter.int(windows.LARGE_INTEGER, "CreationTime", info.CreationTime);
            try reporter.int(windows.LARGE_INTEGER, "LastAccessTime", info.LastAccessTime);
            try reporter.int(windows.LARGE_INTEGER, "LastWriteTime", info.LastWriteTime);
            try reporter.int(windows.LARGE_INTEGER, "ChangeTime", info.ChangeTime);
            try reporter.int(windows.LARGE_INTEGER, "AllocationSize", info.AllocationSize);
            try reporter.int(windows.LARGE_INTEGER, "EndOfFile", info.EndOfFile);
            try reporter.int(windows.ULONG, "FileAttributes", info.FileAttributes);
            try reporter.int(windows.ULONG, "ReparseTag", info.ReparseTag);
            try reporter.int(windows.ULONG, "NumberOfLinks", info.NumberOfLinks);
        },
        else => @panic("TODO"),
    }
}

const classes = std.enums.values(windows.FILE_INFORMATION_CLASS);

const max_buf_size: usize = blk: {
    var max: usize = 0;
    for (classes) |val| {
        const size = bufSize(val);
        if (size > max) max = size;
    }
    break :blk max;
};

const max_alignment: u29 = blk: {
    var max: u29 = 1;
    for (classes) |val| {
        const T = classToStruct(val) orelse continue;
        const alignment = @alignOf(T);
        if (alignment > max) max = alignment;
    }
    break :blk max;
};

fn classToStruct(class: windows.FILE_INFORMATION_CLASS) ?type {
    return switch (class) {
        .FileBasicInformation => windows.FILE_BASIC_INFORMATION,
        .FileStandardInformation => windows.FILE_STANDARD_INFORMATION,
        .FileInternalInformation => windows.FILE_INTERNAL_INFORMATION,
        .FileEaInformation => windows.FILE_EA_INFORMATION,
        .FileAccessInformation => windows.FILE_ACCESS_INFORMATION,
        .FilePositionInformation => windows.FILE_POSITION_INFORMATION,
        .FileModeInformation => windows.FILE_MODE_INFORMATION,
        .FileAlignmentInformation => windows.FILE_ALIGNMENT_INFORMATION,
        .FileNameInformation => windows.FILE_NAME_INFORMATION,
        .FileAllInformation => windows.FILE_ALL_INFORMATION,
        .FileStatInformation => windows.FILE_STAT_INFORMATION,
        else => null, // TODO
    };
}

fn minBufSize(class: windows.FILE_INFORMATION_CLASS) usize {
    return switch (class) {
        inline else => |c| {
            if (classToStruct(c)) |T| {
                return @sizeOf(T);
            }
            return 0;
        },
    };
}

fn bufSize(class: windows.FILE_INFORMATION_CLASS) usize {
    var size = minBufSize(class);
    size += switch (class) {
        .FileNameInformation,
        .FileAllInformation,
        => windows.PATH_MAX_WIDE * 2,
        else => 0,
    };
    return size;
}

pub const FILE_STAT_INFORMATION = extern struct {
    FileId: windows.LARGE_INTEGER,
    CreationTime: windows.LARGE_INTEGER,
    LastAccessTime: windows.LARGE_INTEGER,
    LastWriteTime: windows.LARGE_INTEGER,
    ChangeTime: windows.LARGE_INTEGER,
    AllocationSize: windows.LARGE_INTEGER,
    EndOfFile: windows.LARGE_INTEGER,
    FileAttributes: windows.ULONG,
    ReparseTag: windows.ULONG,
    NumberOfLinks: windows.ULONG,
    EffectiveAccess: windows.ACCESS_MASK,
};
