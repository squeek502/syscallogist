const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;
const linux = std.os.linux;

pub const FileSystemFlags = switch (builtin.os.tag) {
    .windows => FileSystemFlagsWindows,
    .linux => FileSystemFlagsLinux,
    else => @compileError("TODO"),
};

pub const FilesystemInfo = struct {
    fs_name: []const u8,
    fs_flags: FileSystemFlags,
    max_component_length: u32,

    pub fn deinit(self: FilesystemInfo, allocator: std.mem.Allocator) void {
        switch (builtin.os.tag) {
            .windows => {
                allocator.free(self.fs_name);
            },
            else => {},
        }
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
        .linux => {
            const statfs = try fstatfs(handle);
            return .{
                .fs_name = magicToFsName(@bitCast(statfs.type)),
                .fs_flags = @bitCast(statfs.flags),
                .max_component_length = @intCast(statfs.namelen),
            };
        },
        else => @compileError("TDOO"),
    }
}

fn fstatfs(fd: i32) !StatFS {
    var statfs = std.mem.zeroes(StatFS);
    switch (errno(fstatfs_syscall(fd, &statfs))) {
        .SUCCESS => return statfs,
        else => |err| return std.posix.unexpectedErrno(err),
    }
}

fn fstatfs_syscall(fd: i32, statfs_buf: *StatFS) usize {
    if (@hasField(linux.SYS, "fstatfs64")) {
        return linux.syscall2(.fstatfs64, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(statfs_buf));
    } else {
        return linux.syscall2(.fstatfs, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(statfs_buf));
    }
}

// Same as std.posix.errno, but doesn't ever use the libc errno
pub fn errno(rc: anytype) std.posix.E {
    const signed: isize = @bitCast(rc);
    const int = if (signed > -4096 and signed < 0) -signed else 0;
    return @enumFromInt(int);
}

const fsblkcnt_t = usize;
const __fsword_t = isize;
const fsfilcnt_t = usize;

pub const StatFS = extern struct {
    type: __fsword_t,
    bsize: __fsword_t,
    blocks: fsblkcnt_t,
    bfree: fsblkcnt_t,
    bavail: fsblkcnt_t,
    files: fsfilcnt_t,
    ffree: fsfilcnt_t,
    fsid: [2]i32,
    namelen: __fsword_t,
    frsize: __fsword_t,
    flags: __fsword_t,
    spare: [4]__fsword_t,
};

fn magicToFsName(magic: usize) []const u8 {
    // From linux/magic.h
    return switch (magic) {
        0xadf5 => "ADFS", // ADFS_SUPER_MAGIC
        0xadff => "AFFS", // AFFS_SUPER_MAGIC
        0x5346414F => "AFS", // AFS_SUPER_MAGIC
        0x0187 => "AUTOFS", // AUTOFS_SUPER_MAGIC
        0x00c36400 => "CEPH", // CEPH_SUPER_MAGIC
        0x73757245 => "CODA", // CODA_SUPER_MAGIC
        0x28cd3d45 => "CRAMFS", // CRAMFS_MAGIC
        0x453dcd28 => "CRAMFS", // CRAMFS_MAGIC_WEND (wrong endian)
        0x64626720 => "DEBUGFS", // DEBUGFS_MAGIC
        0x73636673 => "SECURITYFS", // SECURITYFS_MAGIC
        0xf97cff8c => "SELINUX", // SELINUX_MAGIC
        0x43415d53 => "SMACK", // SMACK_MAGIC
        0x858458f6 => "RAMFS", // RAMFS_MAGIC
        0x01021994 => "TMPFS", // TMPFS_MAGIC
        0x958458f6 => "HUGETLBFS", // HUGETLBFS_MAGIC
        0x73717368 => "SQUASHFS", // SQUASHFS_MAGIC
        0xf15f => "ECRYPTFS", // ECRYPTFS_SUPER_MAGIC
        0x414A53 => "EFS", // EFS_SUPER_MAGIC
        0xE0F5E1E2 => "EROFS", // EROFS_SUPER_MAGIC_V1
        0xabba1974 => "XENFS", // XENFS_SUPER_MAGIC
        0xEF53 => "EXT2/3/4", // EXT2_SUPER_MAGIC, EXT3_SUPER_MAGIC, EXT4_SUPER_MAGIC
        0x9123683E => "BTRFS", // BTRFS_SUPER_MAGIC
        0x3434 => "NILFS", // NILFS_SUPER_MAGIC
        0xF2F52010 => "F2FS", // F2FS_SUPER_MAGIC
        0xf995e849 => "HPFS", // HPFS_SUPER_MAGIC
        0x9660 => "ISOFS", // ISOFS_SUPER_MAGIC
        0x72b6 => "JFFS2", // JFFS2_SUPER_MAGIC
        0x58465342 => "XFS", // XFS_SUPER_MAGIC
        0x6165676C => "PSTOREFS", // PSTOREFS_MAGIC
        0xde5e81e4 => "EFIVARFS", // EFIVARFS_MAGIC
        0x00c0ffee => "HOSTFS", // HOSTFS_SUPER_MAGIC
        0x794c7630 => "OVERLAYFS", // OVERLAYFS_SUPER_MAGIC
        0x65735546 => "FUSE", // FUSE_SUPER_MAGIC
        0x137F => "MINIX_14CHAR", // MINIX_SUPER_MAGIC (minix v1 fs, 14 char names)
        0x138F => "MINIX_30CHAR", // MINIX_SUPER_MAGIC2 (minix v1 fs, 30 char names)
        0x2468 => "MINIX2_14CHAR", // MINIX2_SUPER_MAGIC (minix v2 fs, 14 char names)
        0x2478 => "MINIX2_30CHAR", // MINIX2_SUPER_MAGIC2 (minix v2 fs, 30 char names)
        0x4d5a => "MINIX3_60CHAR", // MINIX3_SUPER_MAGIC (minix v3 fs, 60 char names)
        0x4d44 => "MSDOS", // MSDOS_SUPER_MAGIC
        0x2011BAB0 => "EXFAT", // EXFAT_SUPER_MAGIC
        0x564c => "NCP", // NCP_SUPER_MAGIC
        0x6969 => "NFS", // NFS_SUPER_MAGIC
        0x7461636f => "OCFS2", // OCFS2_SUPER_MAGIC
        0x9fa1 => "OPENPROM", // OPENPROM_SUPER_MAGIC
        0x002f => "QNX4", // QNX4_SUPER_MAGIC
        0x68191122 => "QNX6", // QNX6_SUPER_MAGIC
        0x6B414653 => "AFS_FS", // AFS_FS_MAGIC
        0x52654973 => "REISERFS", // REISERFS_SUPER_MAGIC
        0x517B => "SMB", // SMB_SUPER_MAGIC
        0xFF534D42 => "CIFS", // CIFS_SUPER_MAGIC
        0xFE534D42 => "SMB2", // SMB2_SUPER_MAGIC
        0x27e0eb => "CGROUP", // CGROUP_SUPER_MAGIC
        0x63677270 => "CGROUP2", // CGROUP2_SUPER_MAGIC
        0x7655821 => "RDTGROUP", // RDTGROUP_SUPER_MAGIC
        0x57AC6E9D => "STACK_END", // STACK_END_MAGIC
        0x74726163 => "TRACEFS", // TRACEFS_MAGIC
        0x01021997 => "V9FS", // V9FS_MAGIC
        0x62646576 => "BDEVFS", // BDEVFS_MAGIC
        0x64646178 => "DAXFS", // DAXFS_MAGIC
        0x42494e4d => "BINFMTFS", // BINFMTFS_MAGIC
        0x1cd1 => "DEVPTS", // DEVPTS_SUPER_MAGIC
        0x6c6f6f70 => "BINDERFS", // BINDERFS_SUPER_MAGIC
        0xBAD1DEA => "FUTEXFS", // FUTEXFS_SUPER_MAGIC
        0x50495045 => "PIPEFS", // PIPEFS_MAGIC
        0x9fa0 => "PROC", // PROC_SUPER_MAGIC
        0x534F434B => "SOCKFS", // SOCKFS_MAGIC
        0x62656572 => "SYSFS", // SYSFS_MAGIC
        0x9fa2 => "USBDEVICE", // USBDEVICE_SUPER_MAGIC
        0x11307854 => "MTD_INODE_FS", // MTD_INODE_FS_MAGIC
        0x09041934 => "ANON_INODE_FS", // ANON_INODE_FS_MAGIC
        0x73727279 => "BTRFS_TEST", // BTRFS_TEST_MAGIC
        0x6e736673 => "NSFS", // NSFS_MAGIC
        0xcafe4a11 => "BPF_FS", // BPF_FS_MAGIC
        0x5a3c69f0 => "AAFS", // AAFS_MAGIC
        0x5a4f4653 => "ZONEFS", // ZONEFS_MAGIC
        0x15013346 => "UDF", // UDF_SUPER_MAGIC
        0x13661366 => "BALLOON_KVM", // BALLOON_KVM_MAGIC
        0x58295829 => "ZSMALLOC", // ZSMALLOC_MAGIC
        0x444d4142 => "DMA_BUF", // DMA_BUF_MAGIC
        0x454d444d => "DEVMEM", // DEVMEM_MAGIC
        0x33 => "Z3FOLD", // Z3FOLD_MAGIC
        0xc7571590 => "PPC_CMM", // PPC_CMM_MAGIC
        0x5345434d => "SECRETMEM", // SECRETMEM_MAGIC
        else => "Unknown",
    };
}

pub const FileSystemFlagsLinux = packed struct(usize) {
    /// 1: Mount read-only.
    RDONLY: bool = false,
    /// 2: Ignore suid and sgid bits.
    NOSUID: bool = false,
    /// 4: Disallow access to device special files.
    NODEV: bool = false,
    /// 8: Disallow program execution.
    NOEXEC: bool = false,
    /// 16: Writes are synced at once.
    SYNCHRONOUS: bool = false,
    /// 64: Allow mandatory locks on an FS.
    MANDLOCK: bool = false,
    /// 128: Write on file/directory/symlink.
    WRITE: bool = false,
    /// 256: Append-only file.
    APPEND: bool = false,
    /// 512: Immutable file.
    IMMUTABLE: bool = false,
    /// 1024: Do not update access times.
    NOATIME: bool = false,
    /// 2048: Do not update directory access times.
    NODIRATIME: bool = false,
    /// 4096: Update atime relative to mtime/ctime.
    RELATIME: bool = false,

    _: @Type(.{
        .Int = .{ .signedness = .unsigned, .bits = @bitSizeOf(usize) - 12 },
    }) = 0,
};

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

pub const FileSystemFlagsWindows = packed struct(windows.DWORD) {
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
