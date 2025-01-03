const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const Type = @import("read.zig").Type;

/// Writes RLP-encoded data with the correct prefix and, if needed, size info.
pub fn write_bytes(encoded: []const u8, dest: *std.ArrayList(u8), as_list: bool) !void {
    const len = encoded.len;
    const rlp_type = if (as_list) Type.List else if (len == 1 and encoded[0] < 128) Type.SingleByte else Type.Array;

    switch (rlp_type) {
        .SingleByte => {
            try dest.append(encoded[0]);
            return;
        },
        .Array => {
            if (len < 56) {
                try write_short(128, encoded, dest);
            } else {
                try write_long(183, encoded, dest);
            }
        },
        .List => {
            if (len < 56) {
                try write_short(192, encoded, dest);
            } else {
                try write_long(247, encoded, dest);
            }
        },
    }
}

test write_bytes {
    var result = std.ArrayList(u8).init(testing.allocator);
    defer result.deinit();

    // Single byte
    try write_bytes(&[1]u8{127}, &result, false);
    try testing.expectEqualSlices(u8, &[1]u8{127}, result.items);

    result.shrinkAndFree(0);

    // Short array (note: value 128 forces us to write an array, not single byte)
    try write_bytes(&[1]u8{128}, &result, false);
    try testing.expectEqualSlices(u8, &[_]u8{ (128 + 1), 128 }, result.items);

    result.shrinkAndFree(0);

    // Short list
    try write_bytes(&[_]u8{ 1, 2, 3 }, &result, true);
    try testing.expectEqualSlices(u8, &[_]u8{ (192 + 3), 1, 2, 3 }, result.items);
}

/// Writes a short byte array or list with the given prefix. The size will be added to
/// the prefix.
inline fn write_short(prefix: u8, encoded: []const u8, dest: *std.ArrayList(u8)) !void {
    const component: u8 = @truncate(encoded.len);
    try dest.append(prefix + component);
    if (encoded.len > 0) {
        try dest.appendSlice(encoded);
    }
}

/// Makes sure that unsigned integer is written in canonical format, i.e. there are no leading
/// zeroes.
pub inline fn write_canonical_uint(comptime T: type, value: T, dest: *std.ArrayList(u8)) !usize {
    comptime {
        // Allow only unsigned ints and positive comptime_int
        const typeErr = "write_canonical_uint accepts only uint types and positive comptime_int";
        switch (@typeInfo(T)) {
            .int => |info| {
                if (info.signedness == .signed) @compileError(typeErr);
            },
            .comptime_int => if (value < 0) @compileError(typeErr),
            else => @compileError(typeErr),
        }
    }

    var buf: [@sizeOf(usize)]u8 = undefined;
    mem.writeInt(usize, &buf, value, .big);

    // Trim leading zeroes
    const padding = @clz(value) / 8;
    const trimmed = buf[padding..];

    try dest.appendSlice(trimmed);
    return trimmed.len;
}

test write_canonical_uint {
    var result = std.ArrayList(u8).init(testing.allocator);
    defer result.deinit();

    const value: u64 = 1;
    const written = try write_canonical_uint(u64, value, &result);
    try testing.expectEqualSlices(u8, "\x01", result.items);
    try testing.expect(written == 1);
}

/// Writes a long byte array or list with the given prefix. The size is written
/// after the prefix and the number of bytes taken by the size is added to the prefix.
inline fn write_long(prefix: u8, encoded: []const u8, dest: *std.ArrayList(u8)) !void {
    var size = std.ArrayList(u8).init(dest.allocator);
    defer size.deinit();
    _ = try write_canonical_uint(usize, encoded.len, &size);
    const component: u8 = @truncate(size.items.len);

    try dest.append(prefix + component);
    try dest.appendSlice(size.items);
    try dest.appendSlice(encoded);
}
