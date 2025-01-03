const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const encode = @import("encode.zig");

// This is RLP-encoded ENR record listed here: https://github.com/ethereum/devp2p/blob/master/enr.md#test-vectors
const enr_record = "\xf8\x84\xb8\x40\x70\x98\xad\x86\x5b\x00\xa5\x82\x05\x19\x40\xcb\x9c\xf3\x68\x36\x57\x24\x11\xa4\x72\x78\x78\x30\x77\x01\x15\x99\xed\x5c\xd1\x6b\x76\xf2\x63\x5f\x4e\x23\x47\x38\xf3\x08\x13\xa8\x9e\xb9\x13\x7e\x3e\x3d\xf5\x26\x6e\x3a\x1f\x11\xdf\x72\xec\xf1\x14\x5c\xcb\x9c\x01\x82\x69\x64\x82\x76\x34\x82\x69\x70\x84\x7f\x00\x00\x01\x89\x73\x65\x63\x70\x32\x35\x36\x6b\x31\xa1\x03\xca\x63\x4c\xae\x0d\x49\xac\xb4\x01\xd8\xa4\xc6\xb6\xfe\x8c\x55\xb7\x0d\x11\x5b\xf4\x00\x76\x9c\xc1\x40\x0f\x32\x58\xcd\x31\x38\x83\x75\x64\x70\x82\x76\x5f";
const enr_signature = "\x70\x98\xad\x86\x5b\x00\xa5\x82\x05\x19\x40\xcb\x9c\xf3\x68\x36\x57\x24\x11\xa4\x72\x78\x78\x30\x77\x01\x15\x99\xed\x5c\xd1\x6b\x76\xf2\x63\x5f\x4e\x23\x47\x38\xf3\x08\x13\xa8\x9e\xb9\x13\x7e\x3e\x3d\xf5\x26\x6e\x3a\x1f\x11\xdf\x72\xec\xf1\x14\x5c\xcb\x9c";

test "encode ENR record" {
    // Since RLP records are a list, `result` will hold the list and `items` will hold list body.
    var result = std.ArrayList(u8).init(testing.allocator);
    var items = std.ArrayList(u8).init(testing.allocator);
    defer {
        result.deinit();
        items.deinit();
    }

    try encode.encodeBytes(enr_signature, &items);
    try encode.encodeUint(u8, 1, &items);

    try encode.encodeBytes("id", &items);
    try encode.encodeBytes("v4", &items);

    try encode.encodeBytes("ip", &items);
    try encode.encodeBytes("\x7f\x00\x00\x01", &items);

    try encode.encodeBytes("secp256k1", &items);
    try encode.encodeBytes("\x03\xca\x63\x4c\xae\x0d\x49\xac\xb4\x01\xd8\xa4\xc6\xb6\xfe\x8c\x55\xb7\x0d\x11\x5b\xf4\x00\x76\x9c\xc1\x40\x0f\x32\x58\xcd\x31\x38", &items);

    try encode.encodeBytes("udp", &items);
    try encode.encodeBytes("\x76\x5f", &items);

    try encode.encodeList(items.items, &result);
    try testing.expectEqualSlices(u8, enr_record, result.items);
}

test "encode ENR record with encode()" {
    // Since RLP records are a list, `result` will hold the list and `items` will hold list body.
    var result = std.ArrayList(u8).init(testing.allocator);
    var items = std.ArrayList(u8).init(testing.allocator);
    defer {
        result.deinit();
        items.deinit();
    }

    try encode.encode([]const u8, enr_signature, &items);
    try encode.encode(u8, 1, &items);

    try encode.encode([]const u8, "id", &items);
    try encode.encode([]const u8, "v4", &items);

    try encode.encode([]const u8, "ip", &items);
    try encode.encode([]const u8, "\x7f\x00\x00\x01", &items);

    try encode.encode([]const u8, "secp256k1", &items);
    try encode.encode([]const u8, "\x03\xca\x63\x4c\xae\x0d\x49\xac\xb4\x01\xd8\xa4\xc6\xb6\xfe\x8c\x55\xb7\x0d\x11\x5b\xf4\x00\x76\x9c\xc1\x40\x0f\x32\x58\xcd\x31\x38", &items);

    try encode.encode([]const u8, "udp", &items);
    try encode.encode([]const u8, "\x76\x5f", &items);

    try encode.encodeList(items.items, &result);
    try testing.expectEqualSlices(u8, enr_record, result.items);
}
