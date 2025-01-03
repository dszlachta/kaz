pub const rlp = @import("libkaz-rlp");

test {
    _ = @import("libkaz-rlp");

    @import("std").testing.refAllDeclsRecursive(@This());
}
