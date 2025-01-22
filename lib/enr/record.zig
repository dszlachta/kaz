const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const rlp = @import("../rlp/rlp.zig");

// This is RLP-encoded ENR record listed here: https://github.com/ethereum/devp2p/blob/master/enr.md#test-vectors
const test_enr_bytes = "\xf8\x84\xb8\x40\x70\x98\xad\x86\x5b\x00\xa5\x82\x05\x19\x40\xcb\x9c\xf3\x68\x36\x57\x24\x11\xa4\x72\x78\x78\x30\x77\x01\x15\x99\xed\x5c\xd1\x6b\x76\xf2\x63\x5f\x4e\x23\x47\x38\xf3\x08\x13\xa8\x9e\xb9\x13\x7e\x3e\x3d\xf5\x26\x6e\x3a\x1f\x11\xdf\x72\xec\xf1\x14\x5c\xcb\x9c\x01\x82\x69\x64\x82\x76\x34\x82\x69\x70\x84\x7f\x00\x00\x01\x89\x73\x65\x63\x70\x32\x35\x36\x6b\x31\xa1\x03\xca\x63\x4c\xae\x0d\x49\xac\xb4\x01\xd8\xa4\xc6\xb6\xfe\x8c\x55\xb7\x0d\x11\x5b\xf4\x00\x76\x9c\xc1\x40\x0f\x32\x58\xcd\x31\x38\x83\x75\x64\x70\x82\x76\x5f";
const test_signature = "\x70\x98\xad\x86\x5b\x00\xa5\x82\x05\x19\x40\xcb\x9c\xf3\x68\x36\x57\x24\x11\xa4\x72\x78\x78\x30\x77\x01\x15\x99\xed\x5c\xd1\x6b\x76\xf2\x63\x5f\x4e\x23\x47\x38\xf3\x08\x13\xa8\x9e\xb9\x13\x7e\x3e\x3d\xf5\x26\x6e\x3a\x1f\x11\xdf\x72\xec\xf1\x14\x5c\xcb\x9c";

pub const EnrParseErrors = error{
    InvalidFormat,
};

pub const Enr = struct {
    allocator: mem.Allocator,

    signature: []u8,
    sequence: u64,
    pairs: std.StringHashMap([]const u8),

    pub fn init(allocator: mem.Allocator) Enr {
        return .{
            .allocator = allocator,
            .signature = undefined,
            .sequence = 0,
            .pairs = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Enr) void {
        self.allocator.free(self.signature);

        // var keyIter = map.keyIterator();
        // while (keyIter.next()) |key| {
        //     std.testing.allocator.free(key.*);
        // }
        var it = self.pairs.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.pairs.deinit();
    }

    pub fn decode(self: *Enr, base64: []const u8) !void {
        if (!mem.startsWith(u8, base64, "enr:")) {
            return EnrParseErrors.InvalidFormat;
        }
        const without_prefix = base64[4..base64.len]; // base64[4..][0 .. base64.len - 4];
        const decoder = std.base64.url_safe_no_pad.Decoder;

        const size = try decoder.calcSizeForSlice(without_prefix);
        const dest = try self.allocator.alloc(u8, size);
        defer self.allocator.free(dest);

        try decoder.decode(dest, without_prefix);

        try self.decodeBytes(dest);
    }

    test decode {
        var record = Enr.init(testing.allocator);
        defer record.deinit();

        try record.decode("enr:-IS4QHCYrYZbAKWCBRlAy5zzaDZXJBGkcnh4MHcBFZntXNFrdvJjX04jRzjzCBOonrkTfj499SZuOh8R33Ls8RRcy5wBgmlkgnY0gmlwhH8AAAGJc2VjcDI1NmsxoQPKY0yuDUmstAHYpMa2_oxVtw0RW_QAdpzBQA8yWM0xOIN1ZHCCdl8");
        try testing.expectEqualSlices(u8, test_signature, record.signature);
        try testing.expect(record.sequence == 1);

        // pairs

        try testing.expectEqualSlices(u8, "v4", record.pairs.get("id") orelse unreachable);
        try testing.expectEqualSlices(u8, "\x7f\x00\x00\x01", record.pairs.get("ip") orelse unreachable);
        try testing.expectEqualSlices(u8, "\x03\xca\x63\x4c\xae\x0d\x49\xac\xb4\x01\xd8\xa4\xc6\xb6\xfe\x8c\x55\xb7\x0d\x11\x5b\xf4\x00\x76\x9c\xc1\x40\x0f\x32\x58\xcd\x31\x38", record.pairs.get("secp256k1") orelse unreachable);
        try testing.expectEqualSlices(u8, "\x76\x5f", record.pairs.get("udp") orelse unreachable);
    }

    pub fn decodeBytes(self: *Enr, bytes: []const u8) !void {
        const list_result = try rlp.decode.decodeList(bytes);
        const sig_result = try rlp.decode.decodeBytes(list_result.value);
        self.signature = try self.allocator.dupe(u8, sig_result.value);

        var position = sig_result.read;

        const seq_result = try rlp.decode.decodeUint(u64, list_result.value[position..]);
        self.sequence = seq_result.value;

        position += seq_result.read;

        // const pairs_size = listResult.read - sigResult.read - 8;

        // TODO: make sure decodeBytes handles being called when pairs is initialized
        // (e.g. reusing the object) - otherwise we change the ref here and get memory
        // leak. Can error or deinit before init
        self.pairs = std.StringHashMap([]const u8).init(self.allocator);
        while (position < list_result.value.len) {
            const keyResult = try rlp.decode.decodeBytes(list_result.value[position..]);
            position += keyResult.read;

            const valueResult = try rlp.decode.decodeBytes(list_result.value[position..]);
            position += valueResult.read;

            const key = try self.pairs.allocator.dupe(u8, keyResult.value);
            const value = try self.pairs.allocator.dupe(u8, valueResult.value);

            try self.pairs.put(key, value);
        }
    }

    test decodeBytes {
        const raw = std.mem.asBytes(test_enr_bytes);

        var record = Enr.init(testing.allocator);
        defer record.deinit();
        try record.decodeBytes(raw);

        try testing.expectEqualSlices(u8, test_signature, record.signature);
        try testing.expect(record.sequence == 1);

        // pairs

        try testing.expectEqualSlices(u8, "v4", record.pairs.get("id") orelse unreachable);
        try testing.expectEqualSlices(u8, "\x7f\x00\x00\x01", record.pairs.get("ip") orelse unreachable);
        try testing.expectEqualSlices(u8, "\x03\xca\x63\x4c\xae\x0d\x49\xac\xb4\x01\xd8\xa4\xc6\xb6\xfe\x8c\x55\xb7\x0d\x11\x5b\xf4\x00\x76\x9c\xc1\x40\x0f\x32\x58\xcd\x31\x38", record.pairs.get("secp256k1") orelse unreachable);
        try testing.expectEqualSlices(u8, "\x76\x5f", record.pairs.get("udp") orelse unreachable);
    }
};
