const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const Type = @import("read.zig").Type;
const write = @import("write.zig");

/// Encodes values of type: bool, int, comptime_int, arrays of u8 and slices of u8.
pub fn encode(comptime T: type, value: T, dest: *std.ArrayList(u8)) !void {
    switch (@typeInfo(T)) {
        .bool => {
            return encodeBool(value, dest);
        },
        .int, .comptime_int => {
            return encodeUint(T, value, dest);
        },
        .array => |info| {
            if (info.child != u8) {
                @compileError("encode only supports arrays of u8");
            }
            return encodeBytes(&value, dest);
        },
        .pointer => |info| {
            switch (info.size) {
                .one => return encode(info.child, value.*, dest),
                .slice => {
                    if (info.child != u8) {
                        @compileError("encode only supports slices of u8");
                    }
                    return encodeBytes(value, dest);
                },
                else => @compileError("pointer points to unsupported type"),
            }
        },
        else => @compileError("unsupported type"),
    }
}

test encode {
    var result = std.ArrayList(u8).init(testing.allocator);
    defer result.deinit();

    // @clz doesn't want comptime_int despite what the docs say
    // try encode(comptime_int, 1, &result);
    // try testing.expectEqualSlices(u8, "\x01", result.items);

    result.shrinkAndFree(0);
    try encode(u64, 2, &result);
    try testing.expectEqualSlices(u8, "\x02", result.items);

    result.shrinkAndFree(0);
    try encode([]const u8, "doggo", &result);
    try testing.expectEqualSlices(u8, "doggo", result.items[1..]);

    result.shrinkAndFree(0);
    try encode([3]u8, [3]u8{ 1, 2, 3 }, &result);
    try testing.expectEqualSlices(u8, &[3]u8{ 1, 2, 3 }, result.items[1..]);

    result.shrinkAndFree(0);
    try encode(bool, true, &result);
    try testing.expectEqualSlices(u8, "\x01", result.items);

    result.shrinkAndFree(0);
    const u32_value: u32 = 255;
    try encode(*u32, @constCast(&u32_value), &result);
    try testing.expectEqualSlices(u8, "\xff", result.items[1..]);
}

pub fn encodeBool(value: bool, dest: *std.ArrayList(u8)) !void {
    return write.writeBytes(if (value) "\x01" else "\x00", dest, false);
}

test encodeBool {
    var result = std.ArrayList(u8).init(testing.allocator);
    defer result.deinit();

    try encodeBool(true, &result);
    try testing.expectEqualSlices(u8, "\x01", result.items);

    result.shrinkAndFree(0);
    try encodeBool(false, &result);
    try testing.expectEqualSlices(u8, "\x00", result.items);
}

pub fn encodeUint(comptime T: type, value: T, dest: *std.ArrayList(u8)) !void {
    var canonical = std.ArrayList(u8).init(dest.allocator);
    defer canonical.deinit();

    _ = try write.writeCanonicalUint(T, value, &canonical);
    return write.writeBytes(canonical.items, dest, false);
}

test encodeUint {
    var result = std.ArrayList(u8).init(testing.allocator);
    defer result.deinit();

    try encodeUint(u64, 1, &result);
    try testing.expectEqualSlices(u8, "\x01", result.items);
}

pub fn encodeBytes(value: []const u8, dest: *std.ArrayList(u8)) !void {
    return write.writeBytes(value, dest, false);
}

test encodeBytes {
    var result = std.ArrayList(u8).init(testing.allocator);
    defer result.deinit();

    const expected = "doggo";
    try encodeBytes(expected, &result);

    try testing.expectEqualSlices(u8, expected, result.items[1..]);
}

/// Encodes value (which should be RLP-serialized list items) as a list.
pub fn encodeList(value: []const u8, dest: *std.ArrayList(u8)) !void {
    return write.writeBytes(value, dest, true);
}

test encodeList {
    var result = std.ArrayList(u8).init(testing.allocator);
    defer result.deinit();

    const expected = &[_]u8{ 1, 2, 3 };
    try encodeList(expected, &result);

    try testing.expectEqualSlices(u8, expected, result.items[1..]);
}
