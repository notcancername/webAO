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
