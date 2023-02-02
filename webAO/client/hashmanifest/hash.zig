const std = @import("std");
const util = @import("util.zig");
const rot = util.rotl;

// Jenkins 2006 <http://burtleburtle.net/bob/c/lookup3.c>
const Jenkins3 = struct {
    s: [3]u32,

    fn mix(j: *Jenkins3) void {
        j.s[0] -%= j.s[2]; j.s[0] ^= rot(j.s[2], 4); j.s[2] +%= j.s[1];
        j.s[1] -%= j.s[0]; j.s[1] ^= rot(j.s[0], 6); j.s[0] +%= j.s[2];
        j.s[2] -%= j.s[1]; j.s[2] ^= rot(j.s[1], 8); j.s[1] +%= j.s[0];
        j.s[0] -%= j.s[2]; j.s[0] ^= rot(j.s[2],16); j.s[2] +%= j.s[1];
        j.s[1] -%= j.s[0]; j.s[1] ^= rot(j.s[0],19); j.s[0] +%= j.s[2];
        j.s[2] -%= j.s[1]; j.s[2] ^= rot(j.s[1], 4); j.s[1] +%= j.s[0];
    }

    fn final(j: *Jenkins3) void {
        j.s[2] ^= j.s[1]; j.s[2] -%= rot(j.s[1], 14);
        j.s[0] ^= j.s[2]; j.s[0] -%= rot(j.s[2], 11);
        j.s[1] ^= j.s[0]; j.s[1] -%= rot(j.s[0], 25);
        j.s[2] ^= j.s[1]; j.s[2] -%= rot(j.s[1], 16);
        j.s[0] ^= j.s[2]; j.s[0] -%= rot(j.s[2],  4);
        j.s[1] ^= j.s[0]; j.s[1] -%= rot(j.s[0], 14);
        j.s[2] ^= j.s[1]; j.s[2] -%= rot(j.s[1], 24);
    }

    // XXX: This is ugly. Unfortunately, Zig does not have fallthrough.
    fn loadPartial(j: *Jenkins3, slice: []const u8) bool {
        switch (slice.len) {
            12 => {
                j.s[2] +%= std.mem.readIntLittle(u32, slice[8..12]);
                j.s[1] +%= std.mem.readIntLittle(u32, slice[4..8]);
                j.s[0] +%= std.mem.readIntLittle(u32, slice[0..4]);
            },
            11 => {
                j.s[2] +%= @as(u32, slice[10]) << 16;
                j.s[2] +%= @as(u32, slice[9]) << 8;
                j.s[2] +%= slice[8];
                j.s[1] +%= std.mem.readIntLittle(u32, slice[4..8]);
                j.s[0] +%= std.mem.readIntLittle(u32, slice[0..4]);
            },
            10 => {
                j.s[2] +%= @as(u32, slice[9]) << 8;
                j.s[2] +%= slice[8];
                j.s[1] +%= std.mem.readIntLittle(u32, slice[4..8]);
                j.s[0] +%= std.mem.readIntLittle(u32, slice[0..4]);
            },
            9 => {
                j.s[2]  +%= slice[8];
                j.s[1] +%= std.mem.readIntLittle(u32, slice[4..8]);
                j.s[0] +%= std.mem.readIntLittle(u32, slice[0..4]);
            },
            8 => {
                j.s[1] +%= std.mem.readIntLittle(u32, slice[4..8]);
                j.s[0] +%= std.mem.readIntLittle(u32, slice[0..4]);
            },
            7 => {
                j.s[1] +%= @as(u32, slice[6]) << 16;
                j.s[1] +%= @as(u32, slice[5]) << 8;
                j.s[1] +%= slice[4];
                j.s[0] +%= std.mem.readIntLittle(u32, slice[0..4]);
            },
            6 => {
                j.s[1] +%= @as(u32, slice[5]) << 8;
                j.s[1] +%= slice[4];
                j.s[0] +%= std.mem.readIntLittle(u32, slice[0..4]);
            },
            5 => {
                j.s[1] +%= slice[4];
                j.s[0] +%= std.mem.readIntLittle(u32, slice[0..4]);
            },
            4 => {
                j.s[0] +%= std.mem.readIntLittle(u32, slice[0..4]);
            },
            3 => {
                j.s[0] +%= @as(u32, slice[2]) << 16;
                j.s[0] +%= @as(u32, slice[1]) << 8;
                j.s[0] +%= slice[0];
            },
            2 => {
                j.s[0] +%= @as(u32, slice[1]) << 8;
                j.s[0] +%= slice[0];
            },
            1 => {
                j.s[0] +%= slice[0];
            },
            0 => return false,
            else => {},
        }
        return true;
    }

    fn hashLittle(j: *Jenkins3, bytes: []const u8, seed: u32) void {
        const in: u32 = 0xdeadbeef +% @truncate(u32, bytes.len) +% seed;
        j.s = [_]u32{in, in, in};
        var k = bytes;

        while(k.len > 12) {
            j.s[0] +%= std.mem.readIntLittle(u32, k[0..4]);
            j.s[1] +%= std.mem.readIntLittle(u32, k[4..8]);
            j.s[2] +%= std.mem.readIntLittle(u32, k[8..12]);
            j.mix();
            k = k[12..];
        }
        if(j.loadPartial(k))
            j.final();
    }

    fn finish(j: *Jenkins3, comptime T: type) T {
        return switch(T) {
            u32 => j.s[2],
            u64 => (@as(u64, j.s[1]) << 32) | j.s[2],
            u96 => (@as(u96, j.s[0]) << 64) | (@as(u64, j.s[1]) << 32) | j.s[2],
            else => @compileError("invalid type"),
        };
    }

    fn hash(comptime T: type, bytes: []const u8, seed: u32) T {
        var j: Jenkins3 = undefined;
        j.hashLittle(bytes, seed);
        return j.finish(T);
    }
};

test "Jenkins3.hash"  {
    const ts = "Four score and seven years ago";
    try std.testing.expectEqual(Jenkins3.hash(u32, "", 0), 0xdeadbeef);
    try std.testing.expectEqual(Jenkins3.hash(u64, "", 0), 0xdeadbeefdeadbeef);
    try std.testing.expectEqual(Jenkins3.hash(u96, "", 0), 0xdeadbeefdeadbeefdeadbeef);
    try std.testing.expectEqual(Jenkins3.hash(u32, ts, 0), 0x17770551);
    try std.testing.expectEqual(Jenkins3.hash(u64, ts, 0), 0xce7226e617770551);
}
