const std = @import("std");
const testing = std.testing;
const mem = std.mem;

pub const ReadErrors = error{
    InputTooShort,
};

/// Carries information about read RLP-encoded data:
/// - type: is it a single byte, array of bytes or list?
/// - value: raw bytes representing the data, without RLP prefix(es)
///   Note: for lists, each item will contains its prefix(es)
/// - read: how many bytes were read
pub const Result = struct {
    value: []const u8,
    read: u64,
    type: Type,
};

pub const Type = enum {
    SingleByte,
    Array,
    List,
};

inline fn assertLen(expected: usize, actual: usize) error{InputTooShort}!void {
    if (actual < expected) return ReadErrors.InputTooShort;
}

/// Reads RLP-encoded data based on the prefix and, if present, size info.
/// Note that read_bytes does not check for non-canonical number encoding,
/// because it doesn't know what it's reading.
pub fn readBytes(encoded: []const u8) !Result {
    try assertLen(1, encoded.len);

    return switch (encoded[0]) {
        // single byte
        0...127 => Result{ .value = &[1]u8{encoded[0]}, .read = 1, .type = Type.SingleByte },

        // short byte array (fewer than 56 bytes of content)
        128...183 => readShort(encoded, Type.Array, 128),

        // long byte array (fewer than 2^64 bytes of content)
        184...191 => readLong(encoded, Type.Array, 183),

        // short list (total item length less than 56 bytes)
        192...247 => readShort(encoded, Type.List, 192),

        // long list (total item length less than 2^64 bytes)
        248...255 => readLong(encoded, Type.List, 247),
    };
}

test readBytes {
    try testing.expectEqualDeep(Result{ .read = 2, .value = &[_]u8{1}, .type = Type.Array }, try readBytes(&[_]u8{ 129, 1 }));
}

inline fn readShort(encoded: []const u8, result_type: Type, comptime size_base: comptime_int) ReadErrors!Result {
    const size = encoded[0] - size_base;
    if (size == 0) {
        return Result{ .value = &[1]u8{encoded[0]}, .read = 1, .type = result_type };
    }
    try assertLen(1 + size, encoded.len); // prefix + size

    const value = encoded[1 .. size + 1];
    return Result{
        .read = 1 + size,
        .value = value,
        .type = result_type,
    };
}

inline fn readLong(encoded: []const u8, result_type: Type, comptime size_base: comptime_int) ReadErrors!Result {
    const size_len = encoded[0] - size_base;
    const value_start = 1 + size_len; // prefix + size_len
    try assertLen(value_start, encoded.len);

    const size = std.mem.readVarInt(u64, encoded[1..value_start], .big);
    try assertLen(size + value_start, encoded.len);

    const value = encoded[value_start .. value_start + size];
    return Result{
        .read = value_start + size,
        .value = value,
        .type = result_type,
    };
}
