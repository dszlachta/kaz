const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const Type = @import("read.zig").Type;
const SpecialPrefixes = @import("decode.zig").SpecialPrefixes;

/// Writes RLP-encoded data with the correct prefix and, if needed, size info.
pub fn writeBytes(encoded: []const u8, dest: *std.ArrayList(u8), as_list: bool) !void {
    const len = encoded.len;
    const rlp_type = if (as_list) Type.List else if (len == 1 and encoded[0] < 128) Type.SingleByte else Type.Array;

    switch (rlp_type) {
        .SingleByte => {
            try dest.append(encoded[0]);
            return;
        },
        .Array => {
            if (len < 56) {
                try writeShort(128, encoded, dest);
            } else {
                try writeLong(183, encoded, dest);
            }
        },
        .List => {
            if (len < 56) {
                try writeShort(192, encoded, dest);
            } else {
                try writeLong(247, encoded, dest);
            }
        },
    }
}

test writeBytes {
    var result = std.ArrayList(u8).init(testing.allocator);
    defer result.deinit();

    // Single byte
    try writeBytes(&[1]u8{127}, &result, false);
    try testing.expectEqualSlices(u8, &[1]u8{127}, result.items);

    result.shrinkAndFree(0);

    // Short array (note: value 128 forces us to write an array, not single byte)
    try writeBytes(&[1]u8{128}, &result, false);
    try testing.expectEqualSlices(u8, &[_]u8{ (128 + 1), 128 }, result.items);

    result.shrinkAndFree(0);

    // Short list
    try writeBytes(&[_]u8{ 1, 2, 3 }, &result, true);
    try testing.expectEqualSlices(u8, &[_]u8{ (192 + 3), 1, 2, 3 }, result.items);
}

/// Writes a short byte array or list with the given prefix. The size will be added to
/// the prefix.
inline fn writeShort(prefix: u8, encoded: []const u8, dest: *std.ArrayList(u8)) !void {
    const component: u8 = @truncate(encoded.len);
    try dest.append(prefix + component);
    if (encoded.len > 0) {
        try dest.appendSlice(encoded);
    }
}

/// Makes sure that unsigned integer is written in canonical format, i.e. there are no leading
/// zeroes.
pub inline fn writeCanonicalUint(comptime T: type, value: T, dest: *std.ArrayList(u8)) !usize {
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

    if (value == 0) {
        // Since no leading 0 is allowed, the spec forces us to use 128 (empty array)
        // as a value here
        try dest.append(@intFromEnum(SpecialPrefixes.emptyArray));
        return 1;
    }

    var buf: [@sizeOf(T)]u8 = undefined;
    mem.writeInt(T, &buf, value, .big);

    // Trim leading zeroes
    const padding = @clz(value) / 8;
    const trimmed = buf[padding..];

    try dest.appendSlice(trimmed);
    return trimmed.len;
}

test writeCanonicalUint {
    var result = std.ArrayList(u8).init(testing.allocator);
    defer result.deinit();

    const value: u64 = 1;
    const written = try writeCanonicalUint(u64, value, &result);
    try testing.expectEqualSlices(u8, "\x01", result.items);
    try testing.expect(written == 1);
}

/// Writes a long byte array or list with the given prefix. The size is written
/// after the prefix and the number of bytes taken by the size is added to the prefix.
inline fn writeLong(prefix: u8, encoded: []const u8, dest: *std.ArrayList(u8)) !void {
    var size = std.ArrayList(u8).init(dest.allocator);
    defer size.deinit();
    _ = try writeCanonicalUint(usize, encoded.len, &size);
    const component: u8 = @truncate(size.items.len);

    try dest.append(prefix + component);
    try dest.appendSlice(size.items);
    try dest.appendSlice(encoded);
}
