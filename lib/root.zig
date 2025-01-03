pub const rlp = @import("libkaz_rlp");

test {
    _ = @import("libkaz_rlp");

    @import("std").testing.refAllDeclsRecursive(@This());
}
