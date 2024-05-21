const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;

extern "kernel32" fn GetVolumeInformationByHandleW(
    hFile: windows.HANDLE,
    lpVolumeNameBuffer: ?windows.LPWSTR,
    nVolumeNameSize: windows.DWORD,
    lpVolumeSerialNumber: ?*windows.DWORD,
    lpMaximumComponentLength: ?*windows.DWORD,
    lpFileSystemFlags: ?*windows.DWORD,
    lpFileSystemNameBuffer: ?windows.LPWSTR,
    nFileSystemNameSize: windows.DWORD,
) callconv(windows.WINAPI) windows.BOOLEAN;

const FilesystemInfo = struct {
    fs_name: []const u8,
    fs_flags: FileSystemFlags,
    max_component_length: u32,

    pub fn deinit(self: FilesystemInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.fs_name);
    }
};

pub fn getFileystemInfo(allocator: std.mem.Allocator, handle: std.fs.File.Handle) !FilesystemInfo {
    switch (builtin.os.tag) {
        .windows => {
            var max_component_length: windows.DWORD = undefined;
            var fs_flags: FileSystemFlags = undefined;
            var fs_name_buf: [windows.MAX_PATH:0]u16 = undefined;
            if (GetVolumeInformationByHandleW(
                handle,
                null,
                0,
                null,
                &max_component_length,
                @ptrCast(&fs_flags),
                &fs_name_buf,
                fs_name_buf.len + 1,
            ) == 0) {
                switch (windows.kernel32.GetLastError()) {
                    else => |e| return windows.unexpectedError(e),
                }
            }
            const fs_name_w = std.mem.sliceTo(&fs_name_buf, 0);
            return .{
                .fs_name = try std.unicode.wtf16LeToWtf8Alloc(allocator, fs_name_w),
                .fs_flags = fs_flags,
                .max_component_length = max_component_length,
            };
        },
        else => @compileError("TDOO"),
    }
}

pub const FileSystemFlags = packed struct(windows.DWORD) {
    /// 0x00000001: The specified volume supports case-sensitive file names.
    CASE_SENSITIVE_SEARCH: bool = false,

    /// 0x00000002: The specified volume supports preserved case of file names
    /// when it places a name on disk.
    CASE_PRESERVED_NAMES: bool = false,

    /// 0x00000004: The specified volume supports Unicode in file names as they
    /// appear on disk.
    UNICODE_ON_DISK: bool = false,

    /// 0x00000008: The specified volume preserves and enforces access control
    /// lists (ACL). For example, the NTFS file system preserves and enforces
    /// ACLs, and the FAT file system does not.
    PERSISTENT_ACLS: bool = false,

    /// 0x00000010: The specified volume supports file-based compression.
    FILE_COMPRESSION: bool = false,

    /// 0x00000020: The specified volume supports disk quotas.
    VOLUME_QUOTAS: bool = false,

    /// 0x00000040: The specified volume supports sparse files.
    SUPPORTS_SPARSE_FILES: bool = false,

    /// 0x00000080: The specified volume supports re-parse points.
    SUPPORTS_REPARSE_POINTS: bool = false,

    _8: u7 = 0,

    /// 0x00008000: The specified volume is a compressed volume, for example, a
    /// DoubleSpace volume.
    VOLUME_IS_COMPRESSED: bool = false,

    /// 0x00010000: The specified volume supports object identifiers.
    SUPPORTS_OBJECT_IDS: bool = false,

    /// 0x00020000: The specified volume supports the Encrypted File System
    /// (EFS). For more information, see File Encryption.
    SUPPORTS_ENCRYPTION: bool = false,

    /// 0x00040000: The specified volume supports named streams.
    NAMED_STREAMS: bool = false,

    /// 0x00080000: The specified volume is read-only.
    READ_ONLY_VOLUME: bool = false,

    /// 0x00100000: The specified volume supports a single sequential write.
    SEQUENTIAL_WRITE_ONCE: bool = false,

    /// 0x00200000: The specified volume supports transactions. For more
    /// information, see About KTM.
    SUPPORTS_TRANSACTIONS: bool = false,

    /// 0x00400000: The specified volume supports hard links. For more
    /// information, see Hard Links and Junctions.
    /// Windows Vista and Windows Server 2008: This value is not supported.
    SUPPORTS_HARD_LINKS: bool = false,

    /// 0x00800000: The specified volume supports extended attributes. An
    /// extended attribute is a piece of application-specific metadata that an
    /// application can associate with a file and is not part of the file's
    /// data.
    /// Windows Vista and Windows Server 2008: This value is not supported.
    SUPPORTS_EXTENDED_ATTRIBUTES: bool = false,

    /// 0x01000000: The file system supports open by FileID. For more
    /// information, see FILE_ID_BOTH_DIR_INFO.
    /// Windows Vista and Windows Server 2008: This value is not supported.
    SUPPORTS_OPEN_BY_FILE_ID: bool = false,

    /// 0x02000000: The specified volume supports update sequence number
    /// (USN) journals. For more information, see Change Journal Records.
    /// Windows Vista and Windows Server 2008:  This value is not supported.
    SUPPORTS_USN_JOURNAL: bool = false,

    _27: u1 = 0,

    /// 0x08000000: The specified volume supports sharing logical clusters
    /// between files on the same volume. The file system reallocates on writes
    /// to shared clusters. Indicates that FSCTL_DUPLICATE_EXTENTS_TO_FILE is a
    /// supported operation.
    SUPPORTS_BLOCK_REFCOUNTING: bool = false,

    _: u4 = 0,
};
