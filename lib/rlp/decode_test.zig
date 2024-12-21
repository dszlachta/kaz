const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const decode = @import("./decode.zig");

test "decodeBool" {
    try testing.expectEqual(decode.DecodeResult(bool){ .value = false, .read = 1 }, try decode.decodeBool(&[_]u8{0x0}));
    try testing.expectEqual(decode.DecodeResult(bool){ .value = true, .read = 1 }, try decode.decodeBool(&[_]u8{0x1}));
    try testing.expectError(decode.DecodeErrors.ExpectedBoolean, decode.decodeBool(&[_]u8{0x2}));
}

test "decodeUint" {
    try testing.expectError(decode.DecodeErrors.NonCanonicalUintEncoding, decode.decodeUint(u8, &[_]u8{0}));
    try testing.expectEqual(decode.DecodeResult(u8){ .value = 0x7f, .read = 1 }, try decode.decodeUint(u8, &[_]u8{0x7f}));
    try testing.expectEqual(decode.DecodeResult(u8){ .value = 0, .read = 1 }, try decode.decodeUint(u8, &[_]u8{@intFromEnum(decode.SpecialPrefixes.emptyArray)}));

    const maxInt = std.math.maxInt;
    try testing.expectEqual(decode.DecodeResult(u8){ .value = maxInt(u8), .read = 2 }, try decode.decodeUint(u8, &[_]u8{128 + 1} ++ &[_]u8{0xff} ** 1));
    try testing.expectEqual(decode.DecodeResult(u16){ .value = maxInt(u16), .read = 3 }, try decode.decodeUint(u16, &[_]u8{128 + 2} ++ &[_]u8{0xff} ** 2));
    try testing.expectEqual(decode.DecodeResult(u32){ .value = maxInt(u32), .read = 5 }, try decode.decodeUint(u32, &[_]u8{128 + 4} ++ &[_]u8{0xff} ** 4));
}

test "decodeBytes" {
    try testing.expectEqualDeep(decode.DecodeResult([]const u8){ .value = "", .read = 1 }, try decode.decodeBytes(&[_]u8{@intFromEnum(decode.SpecialPrefixes.emptyArray)}));
    try testing.expectEqualDeep(decode.DecodeResult([]const u8){ .value = "z", .read = 1 }, try decode.decodeBytes(&[_]u8{0x7a}));
    try testing.expectEqualDeep(decode.DecodeResult([]const u8){ .value = "dog", .read = 4 }, try decode.decodeBytes(&[_]u8{0x83} ++ "dog"));
    try testing.expectEqualDeep(decode.DecodeResult([]const u8){ .value = "Lorem ipsum dolor sit amet, consectetur adipisicing elit", .read = 58 }, try decode.decodeBytes(&[_]u8{ 0xb8, 0x38 } ++ "Lorem ipsum dolor sit amet, consectetur adipisicing elit"));
}

test "decodeList" {
    try testing.expectError(decode.DecodeErrors.ExpectedList, decode.decodeList(&[_]u8{127}));

    try testing.expectEqualDeep(decode.DecodeResult([]const u8){ .value = undefined, .read = 1 }, try decode.decodeList(&[_]u8{@intFromEnum(decode.SpecialPrefixes.emptyList)}));

    // This is RLP-encoded ENR record listed here: https://github.com/ethereum/devp2p/blob/master/enr.md#test-vectors
    const record_bytes = "\xf8\x84\xb8\x40\x70\x98\xad\x86\x5b\x00\xa5\x82\x05\x19\x40\xcb\x9c\xf3\x68\x36\x57\x24\x11\xa4\x72\x78\x78\x30\x77\x01\x15\x99\xed\x5c\xd1\x6b\x76\xf2\x63\x5f\x4e\x23\x47\x38\xf3\x08\x13\xa8\x9e\xb9\x13\x7e\x3e\x3d\xf5\x26\x6e\x3a\x1f\x11\xdf\x72\xec\xf1\x14\x5c\xcb\x9c\x01\x82\x69\x64\x82\x76\x34\x82\x69\x70\x84\x7f\x00\x00\x01\x89\x73\x65\x63\x70\x32\x35\x36\x6b\x31\xa1\x03\xca\x63\x4c\xae\x0d\x49\xac\xb4\x01\xd8\xa4\xc6\xb6\xfe\x8c\x55\xb7\x0d\x11\x5b\xf4\x00\x76\x9c\xc1\x40\x0f\x32\x58\xcd\x31\x38\x83\x75\x64\x70\x82\x76\x5f";
    const raw_enr_record = std.mem.asBytes(record_bytes);

    const listResult = try decode.decodeList(raw_enr_record);
    try testing.expect(listResult.read > 0);
    try testing.expectEqual(0x84, listResult.value.len);

    const sigResult = try decode.decodeBytes(listResult.value);

    try testing.expectEqualDeep("\x70\x98\xad\x86\x5b\x00\xa5\x82\x05\x19\x40\xcb\x9c\xf3\x68\x36\x57\x24\x11\xa4\x72\x78\x78\x30\x77\x01\x15\x99\xed\x5c\xd1\x6b\x76\xf2\x63\x5f\x4e\x23\x47\x38\xf3\x08\x13\xa8\x9e\xb9\x13\x7e\x3e\x3d\xf5\x26\x6e\x3a\x1f\x11\xdf\x72\xec\xf1\x14\x5c\xcb\x9c", sigResult.value);
    var position = sigResult.read;

    const seqResult = try decode.decodeUint(u64, listResult.value[position..]);
    try testing.expectEqual(1, seqResult.value);
    position += seqResult.read;

    const pairs_size = listResult.read - sigResult.read - 8;
    try testing.expect(pairs_size > 0);

    var pairs = std.ArrayList([2][]const u8).init(testing.allocator);
    defer pairs.deinit();

    while (position < listResult.value.len) {
        const keyResult = try decode.decodeBytes(listResult.value[position..]);
        position += keyResult.read;

        const valueResult = try decode.decodeBytes(listResult.value[position..]);
        position += valueResult.read;

        try pairs.append([2][]const u8{ keyResult.value, valueResult.value });
    }

    try testing.expectEqual(4, pairs.items.len);
    try testing.expectEqualDeep("id", pairs.items[0][0]);
    try testing.expectEqualDeep("v4", pairs.items[0][1]);

    try testing.expectEqualDeep("ip", pairs.items[1][0]);
    try testing.expectEqualDeep("\x7f\x00\x00\x01", pairs.items[1][1]);

    try testing.expectEqualDeep("secp256k1", pairs.items[2][0]);
    try testing.expectEqualDeep("\x03\xca\x63\x4c\xae\x0d\x49\xac\xb4\x01\xd8\xa4\xc6\xb6\xfe\x8c\x55\xb7\x0d\x11\x5b\xf4\x00\x76\x9c\xc1\x40\x0f\x32\x58\xcd\x31\x38", pairs.items[2][1]);

    try testing.expectEqualDeep("udp", pairs.items[3][0]);
    try testing.expectEqualDeep("\x76\x5f", pairs.items[3][1]);
}
