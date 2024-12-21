const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const read = @import("read.zig");

pub const DecodeErrors = error{
    NonCanonicalUintEncoding,
    ExpectedSingleByte,
    ExpectedBoolean,
    ExpectedList,
};

pub const SpecialPrefixes = enum(u8) {
    emptyArray = 128,
    emptyList = 192,
};

/// Wraps decoded value of type T and reports how many bytes
/// has been read.
pub fn DecodeResult(comptime T: type) type {
    return struct {
        value: T,
        read: usize,
    };
}

/// Decodes value as a boolean. Ethereum Yellow Paper doesn't specify boolean encoding
/// for RLP, so we follow go-ethereum: 0 means false, 1 means true. Nethermind seems to
/// parse 1 as true, anything other as false. Older implementations used to interpret 0x80
/// as false.
pub fn decodeBool(encoded: []const u8) !DecodeResult(bool) {
    const read_result = try read.read_bytes(encoded);
    if (read_result.type != read.Type.SingleByte) {
        return DecodeErrors.ExpectedSingleByte;
    }

    switch (read_result.value[0]) {
        0x0 => return DecodeResult(bool){ .value = false, .read = 1 },
        0x1 => return DecodeResult(bool){ .value = true, .read = 1 },
        else => return DecodeErrors.ExpectedBoolean,
    }
}

test decodeBool {
    try testing.expectEqual(DecodeResult(bool){ .value = true, .read = 1 }, decodeBool("\x01"));
    try testing.expectEqual(DecodeResult(bool){ .value = false, .read = 1 }, decodeBool("\x00"));
}

pub fn decodeUint(comptime T: type, encoded: []const u8) !DecodeResult(T) {
    comptime {
        const typeErr = "decodeUint accepts only uint types";
        switch (@typeInfo(T)) {
            .int => |info| {
                if (info.signedness == .signed) @compileError(typeErr);
            },
            else => @compileError(typeErr),
        }
    }

    const read_result = try read.read_bytes(encoded);

    if (read_result.read == 1 and read_result.value[0] == 0) {
        return DecodeErrors.NonCanonicalUintEncoding;
    }

    if (read_result.read == 1 and read_result.value[0] == @intFromEnum(SpecialPrefixes.emptyArray)) {
        return DecodeResult(T){ .value = 0, .read = 1 };
    }

    return DecodeResult(T){
        .value = std.mem.readVarInt(T, read_result.value, .big),
        .read = read_result.read,
    };
}

test decodeUint {
    var buffer: [1]u8 = undefined;
    mem.writeInt(u8, &buffer, 255, .big);

    const decoded = try decodeUint(u8, &[_]u8{128 + buffer.len} ++ buffer);
    try testing.expect(decoded.value == 255);
}

pub fn decodeBytes(encoded: []const u8) !DecodeResult([]const u8) {
    const read_result = try read.read_bytes(encoded);

    if (read_result.read == 1 and read_result.value[0] == @intFromEnum(SpecialPrefixes.emptyArray)) {
        return DecodeResult([]const u8){ .value = "", .read = 1 };
    }

    return DecodeResult([]const u8){
        .value = read_result.value,
        .read = read_result.read,
    };
}

test decodeBytes {
    const str = "dog";
    const decoded = try decodeBytes(&[_]u8{128 + str.len} ++ str);
    try testing.expect(std.mem.eql(u8, decoded.value, str));
}

/// Returns RLP-encoded items as value, which can then be passed sequentially
/// to other functions from this file to decode the items.
pub fn decodeList(encoded: []const u8) !DecodeResult([]const u8) {
    const read_result = try read.read_bytes(encoded);

    if (read_result.type != read.Type.List) {
        return DecodeErrors.ExpectedList;
    }

    if (read_result.read == 1 and read_result.value[0] == @intFromEnum(SpecialPrefixes.emptyList)) {
        return DecodeResult([]const u8){ .value = "", .read = 1 };
    }

    return DecodeResult([]const u8){
        .value = read_result.value,
        .read = read_result.read,
    };
}

test decodeList {
    const list = [_]u8{ 192 + 3, 1, 2, 3 };
    const decoded = try decodeList(&list);
    try testing.expectEqualDeep(
        DecodeResult([]const u8){ .value = &[_]u8{ 1, 2, 3 }, .read = 4 },
        decoded,
    );
}
