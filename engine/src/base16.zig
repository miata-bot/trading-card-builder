const std = @import("std");
pub const Error = error{WrongCode};

pub fn Base16(comptime map: *const [16]u8) type {
    return struct {
        pub fn calcSize(len: usize) usize {
            return len * 2;
        }

        pub fn encode(dst: []u8, src: []const u8) void {
            if (dst.len != calcSize(src.len)) @panic("length mismatch");
            for (src) |ch, i| {
                dst[i * 2] = map[(@intCast(usize, ch) >> 4) % 0x10];
                dst[i * 2 + 1] = map[@intCast(usize, ch) % 0x10];
            }
        }

        pub fn encodeFixed(src: anytype) [src.len * 2]u8 {
            var dst: [src.len * 2]u8 = undefined;
            encode(&dst, &src);
            return dst;
        }

        fn getOrigin(ch: u8) ?u8 {
            inline for (map) |x, i| {
                if (x == ch) return @intCast(u8, i);
            }
            return null;
        }

        pub fn decode(dst: []u8, src: []const u8) Error!void {
            if (src.len != calcSize(dst.len)) @panic("length mismatch");
            var rch: u8 = undefined;
            for (src) |ch, i| {
                const origin = getOrigin(ch) orelse return Error.WrongCode;
                if (i % 2 == 0) {
                    rch = origin << 4;
                } else {
                    dst[(i - 1) / 2] = rch | origin;
                }
            }
        }

        pub fn decodeFixed(src: anytype) Error![src.len / 2]u8 {
            const dst: [src.len / 2]u8 = undefined;
            try decode(&dst, src);
            return dst;
        }
    };
}

pub const standard_base16 = Base16("0123456789ABCDEF");

test "encode & decode" {
    var dst: [8]u8 = undefined;
    standard_base16.encode(&dst, "0123");
    try std.testing.expectEqualStrings("30313233", &dst);
    var decoded: [4]u8 = undefined;
    try standard_base16.decode(&decoded, &dst);
    try std.testing.expectEqualStrings("0123", &decoded);
}
