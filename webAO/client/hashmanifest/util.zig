const std = @import("std");

pub fn rotl(v: anytype, amt: anytype) @TypeOf(v) {
    return std.math.rotl(@TypeOf(v), v, amt);
}

test "getLsbs" {
    try std.testing.expectEqual(getLsbs(@as(u8, 0b10101010), 0), 0);
    try std.testing.expectEqual(getLsbs(@as(u8, 0b10101010), 1), 0);
    try std.testing.expectEqual(getLsbs(@as(u8, 0b10101010), 2), 0b10);
    try std.testing.expectEqual(getLsbs(@as(u8, 0b10101010), 3), 0b010);
    try std.testing.expectEqual(getLsbs(@as(u8, 0b10101010), 4), 0b1010);
    try std.testing.expectEqual(getLsbs(@as(u8, 0b10101010), 5), 0b01010);
    try std.testing.expectEqual(getLsbs(@as(u8, 0b10101010), 6), 0b101010);
}
pub fn getLsbs(v: anytype, n: std.math.Log2Int(@TypeOf(v))) @TypeOf(v) {
    const mask = ((@as(@TypeOf(v), 1) << n) - 1);
    return v & mask;
}

pub const unary = struct {
    //! En- and decoding unsigned integers with unary.
    pub fn code(bit_writer: anytype, v: anytype) !void {
        var nb_left = v;
        while(nb_left != 0) : (nb_left -= 1) try bit_writer.writeBits(@as(u1, 0), 1);
        try bit_writer.writeBits(@as(u1, 1), 1);
    }

    pub fn decode(bit_reader: anytype, comptime T: type) !T {
        var result: T = 0;
        while(try bit_reader.readBitsNoEof(u1, 1) == 0)
            result += 1;
        return result;
    }
};

test "unary" {
    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var br = std.io.bitReader(.Big, fbs.reader());
    var bw = std.io.bitWriter(.Big, fbs.writer());
    try unary.code(&bw, @as(u16, 6969));
    try bw.flushBits();
    fbs.reset();
    try std.testing.expectEqual(try unary.decode(&br, u16), 6969);
    br.alignToByte();
    fbs.reset();
}

pub const elias_gamma = struct {
    //! En- and decoding unsigned integers with Elias gamma coding.
    pub fn code(bit_writer: anytype, v: anytype) !void {
        const n = std.math.log2_int(@TypeOf(v), v);
        try unary.code(bit_writer, n);
        try bit_writer.writeBits(v, n);
    }

    pub fn decode(bit_reader: anytype, comptime T: type) !T {
        const n = try unary.decode(bit_reader, std.math.Log2Int(T));
        return (try bit_reader.readBitsNoEof(T, n)) | @as(T, 1) << n;
    }
};

test "elias_gamma" {
    var buf: [4]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var br = std.io.bitReader(.Big, fbs.reader());
    var bw = std.io.bitWriter(.Big, fbs.writer());
    try elias_gamma.code(&bw, @as(u16, 6969));
    try bw.flushBits();
    fbs.reset();
    try std.testing.expectEqual(try elias_gamma.decode(&br, u16), 6969);
    br.alignToByte();
    fbs.reset();
}

pub const exp_golomb = struct {
    //! En- and decoding unsigned integers with exponential Golomb coding.
    pub fn code(bit_writer: anytype, v: anytype, k: std.math.Log2Int(@TypeOf(v))) !void {
        try elias_gamma.code(bit_writer, (v >> k) + 1);
        try bit_writer.writeBits(v, k);
    }

    pub fn decode(bit_reader: anytype, comptime T: type, k: std.math.Log2Int(T)) !T {
        const upper = try elias_gamma.decode(bit_reader, T) - 1;
        return upper << k | try bit_reader.readBitsNoEof(T, k);
    }
};


test "exp_golomb" {
    var buf: [4]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    var br = std.io.bitReader(.Big, fbs.reader());
    var bw = std.io.bitWriter(.Big, fbs.writer());
    try exp_golomb.code(&bw, @as(u16, 6969), 8);
    try bw.flushBits();
    fbs.reset();
    try std.testing.expectEqual(try exp_golomb.decode(&br, u16, 8), 6969);
    br.alignToByte();
    fbs.reset();
}
