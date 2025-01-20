const std = @import("std");
const testing = std.testing;
const rlp = @import("write.zig");

test "write single byte" {
    var al = std.ArrayList(u8).init(testing.allocator);
    defer al.deinit();

    const expected = &[_]u8{10};
    try rlp.writeBytes(expected, &al, false);
    try testing.expectEqualSlices(u8, expected, al.items);
}

test "write short array" {
    var al = std.ArrayList(u8).init(testing.allocator);
    defer al.deinit();

    const expected = &[_]u8{ 128 + 2, 1, 2 };
    try rlp.writeBytes(expected[1..], &al, false);
    try testing.expectEqualSlices(u8, expected, al.items);
}

test "write long array" {
    var al = std.ArrayList(u8).init(testing.allocator);
    defer al.deinit();

    const expected = &[_]u8{ 183 + 1, 56 } ++ (&[1]u8{255} ** 56);
    try rlp.writeBytes(expected[2..], &al, false);
    try testing.expectEqualSlices(u8, expected, al.items);
}

test "write empty array" {
    var al = std.ArrayList(u8).init(testing.allocator);
    defer al.deinit();

    const value: [0]u8 = undefined;
    try rlp.writeBytes(&value, &al, false);
    try testing.expectEqualSlices(u8, &[_]u8{128}, al.items);
}

test "write short list" {
    var al = std.ArrayList(u8).init(testing.allocator);
    defer al.deinit();

    const expected = &[_]u8{ 192 + 2, 1, 2 };
    try rlp.writeBytes(expected[1..], &al, true);
    try testing.expectEqualSlices(u8, expected, al.items);
}

test "write long list" {
    var al = std.ArrayList(u8).init(testing.allocator);
    defer al.deinit();

    const expected = &[_]u8{ 247 + 1, 56 } ++ (&[1]u8{255} ** 56);
    try rlp.writeBytes(expected[2..], &al, true);
    try testing.expectEqualSlices(u8, expected, al.items);
}

test "write empty list" {
    var al = std.ArrayList(u8).init(testing.allocator);
    defer al.deinit();

    const value: [0]u8 = undefined;
    try rlp.writeBytes(&value, &al, true);
    try testing.expectEqualSlices(u8, &[_]u8{192}, al.items);
}

test "write canonical uint" {
    var al = std.ArrayList(u8).init(testing.allocator);
    defer al.deinit();

    _ = try rlp.writeCanonicalUint(u64, 0, &al);
    try testing.expectEqualSlices(u8, &[_]u8{128}, al.items);

    al.shrinkAndFree(0);
    _ = try rlp.writeCanonicalUint(u64, 16, &al);
    try testing.expectEqualSlices(u8, &[_]u8{16}, al.items);
}
