const std = @import("std");
const lib = @import("linearzig");
const types = lib.types;

pub fn main() !void {
    const a = try types.Rational.init(1, 2);
    const b = try types.Rational.init(-3, 4);

    const sum = try a.add(b); // 1/2 + (-3/4) = -1/4
    const diff = try a.sub(b); // 1/2 - (-3/4) = 5/4
    const product = try a.mul(b); // 1/2 * (-3/4) = -3/8
    const quotient = try a.div(b); // 1/2 / (-3/4) = -2/3

    std.debug.print("a = {}\n", .{a}); // "1/2"
    std.debug.print("b = {}\n", .{b}); // "-3/4"
    std.debug.print("a + b = {}\n", .{sum}); // "-1/4"
    std.debug.print("a - b = {}\n", .{diff}); // "5/4"
    std.debug.print("a * b = {}\n", .{product}); // "-3/8"
    std.debug.print("a / b = {}\n", .{quotient}); // "-2/3"

    // Сравнение
    std.debug.print("a < b? {}\n", .{try a.order(b) == .lt}); // false
}
