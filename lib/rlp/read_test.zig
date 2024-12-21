const std = @import("std");
const testing = std.testing;
const read = @import("./read.zig");

test "read_bytes invalid values" {
    // Eempty input
    try testing.expectError(read.ReadErrors.InputTooShort, read.read_bytes(&[0]u8{}));
    // First byte > 127, but input length == 1
    try testing.expectError(read.ReadErrors.InputTooShort, read.read_bytes(&[1]u8{129}));

    // Prefix suggest long array
    try testing.expectError(read.ReadErrors.InputTooShort, read.read_bytes(&[_]u8{(128 + 56)} ++ (&[_]u8{0xff} ** 55)));
    try testing.expectError(read.ReadErrors.InputTooShort, read.read_bytes(&[_]u8{(128 + 56)} ++ (&[_]u8{0xff} ** 56)));
}

test "read_bytes single byte" {
    try testing.expectEqualDeep(read.Result{ .value = "\x00", .read = 1, .type = read.Type.SingleByte }, read.read_bytes("\x00"));
    try testing.expectEqualDeep(read.Result{ .value = &[1]u8{127}, .read = 1, .type = read.Type.SingleByte }, read.read_bytes(&[1]u8{127}));
}

test "read.read_bytes short array" {
    // empty array
    try testing.expectEqualDeep(read.Result{ .value = &[1]u8{128}, .read = 1, .type = read.Type.Array }, read.read_bytes(&[1]u8{128}));
    // few values
    try testing.expectEqualDeep(read.Result{ .value = &[_]u8{1}, .read = 2, .type = read.Type.Array }, read.read_bytes(&[_]u8{ (128 + 1), 1 }));
    try testing.expectEqualDeep(read.Result{ .value = &[_]u8{ 1, 2, 3 }, .read = 4, .type = read.Type.Array }, read.read_bytes(&[_]u8{ (128 + 3), 1, 2, 3 }));
    // max
    try testing.expectEqualDeep(read.Result{ .value = &[_]u8{0xff} ** 55, .read = 56, .type = read.Type.Array }, read.read_bytes(&[_]u8{(128 + 55)} ++ (&[_]u8{0xff} ** 55)));
}

test "read bytes long array" {
    {
        // min value
        const value = &[_]u8{ 184, 56 } ++ "\xff" ** 56;
        const expected = "\xff" ** 56;
        try testing.expectEqualDeep(read.Result{ .value = expected, .read = 58, .type = read.Type.Array }, read.read_bytes(value));
    }
    {
        // large value
        const item = "\xff" ** 1024;
        var size: [8]u8 = undefined;
        std.mem.writeInt(u64, &size, item.len, .big);
        const value = (&[_]u8{(183 + 8)} ++ size) ++ item;
        try testing.expectEqualDeep(read.Result{ .value = item, .read = value.len, .type = read.Type.Array }, read.read_bytes(value));
    }
}

test "read_bytes short list" {
    // empty list
    try testing.expectEqualDeep(read.Result{ .value = &[1]u8{192}, .read = 1, .type = read.Type.List }, read.read_bytes(&[1]u8{192}));

    const items = &[_]u8{133} ++ "hello" ++ [_]u8{133} ++ "world";
    const value = &[_]u8{192 + items.len} ++ items;
    try testing.expectEqualDeep(read.Result{ .value = items, .read = value.len, .type = read.Type.List }, read.read_bytes(value));
}

test "read_bytes long list" {
    const item = &[_]u8{0xff} ** 56;
    const value = &[_]u8{ 248, item.len } ++ item;
    try testing.expectEqualDeep(read.Result{ .value = item, .read = value.len, .type = read.Type.List }, read.read_bytes(value));
}
