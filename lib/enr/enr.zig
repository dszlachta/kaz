pub const record = @import("record.zig");

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
