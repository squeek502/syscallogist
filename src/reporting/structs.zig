pub const Tag = enum(u32) {
    /// name str followed by header(s)
    begin_section,
    /// name str
    end_section,
    /// name str followed by some other data
    field,
    /// int data
    ntstatus,
    /// int data
    errno,
};

pub const Header = extern struct {
    tag: Tag,
};

pub const DataType = enum(u32) {
    str,
    wstr,
    uint,
    int,
};

pub const DataHeader = extern struct {
    type: DataType,
    len: u32,
};
