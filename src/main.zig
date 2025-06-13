const std = @import("std");
const lib = @import("linearzig");
const types = lib.types;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const a = try types.Rational.init(1, 2);
    const b = try types.Rational.init(-3, 4);
    var comps = [_]types.Rational{ a, b };
    const v = try types.Vector.fromRationalComponents(allocator, &comps);
    defer v.deinit();
    std.log.info("Vector: {}", .{v});
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

    var A = try types.Matrix.init(allocator, 4, 4);
    defer A.deinit();

    (try A.atMut(0, 0)).* = try types.Rational.fromInt(2);
    (try A.atMut(0, 1)).* = try types.Rational.fromInt(1);
    (try A.atMut(0, 2)).* = try types.Rational.fromInt(0);
    (try A.atMut(0, 3)).* = try types.Rational.fromInt(0);

    (try A.atMut(1, 0)).* = try types.Rational.fromInt(1);
    (try A.atMut(1, 1)).* = try types.Rational.fromInt(2);
    (try A.atMut(1, 2)).* = try types.Rational.fromInt(1);
    (try A.atMut(1, 3)).* = try types.Rational.fromInt(0);

    (try A.atMut(2, 0)).* = try types.Rational.fromInt(0);
    (try A.atMut(2, 1)).* = try types.Rational.fromInt(1);
    (try A.atMut(2, 2)).* = try types.Rational.fromInt(2);
    (try A.atMut(2, 3)).* = try types.Rational.fromInt(1);

    (try A.atMut(3, 0)).* = try types.Rational.fromInt(0);
    (try A.atMut(3, 1)).* = try types.Rational.fromInt(0);
    (try A.atMut(3, 2)).* = try types.Rational.fromInt(1);
    (try A.atMut(3, 3)).* = try types.Rational.fromInt(2);

    const right_part = [_]i32{ 0, 0, 0, 5 };
    const right = try types.Vector.fromAnyComponents(i32, allocator, &right_part);
    defer right.deinit();
    const x = try A.solve(right);
    defer x.deinit();

    std.log.info("Solved: {}", .{x});

    const row_1 = try types.Vector.fromAnyComponents(i32, allocator, &[_]i32{ 1, 1, 1 });
    defer row_1.deinit();
    const row_2 = try types.Vector.fromAnyComponents(i32, allocator, &[_]i32{ 1, 2, 2 });
    defer row_2.deinit();
    const row_3 = try types.Vector.fromAnyComponents(i32, allocator, &[_]i32{ 2, 3, -4 });
    defer row_3.deinit();
    var rows = [_]types.Vector{ row_1, row_2, row_3 };
    var B = try types.Matrix.init(allocator, 3, 3);
    B.rows = &rows;
    const right_1 = try types.Vector.fromAnyComponents(i32, allocator, &[_]i32{ 6, 11, 3 });
    defer right_1.deinit();
    const x_1 = try B.solve(right_1);
    std.log.info("1: {}", .{x_1});
    const right_2 = try types.Vector.fromAnyComponents(i32, allocator, &[_]i32{ 7, 10, 3 });
    defer right_2.deinit();
    const x_2 = try B.solve(right_2);
    std.log.info("2: {}", .{x_2});
    var sum_x = try types.Rational.fromInt(0);
    var x_1_iter = x_1.iterator();
    while (x_1_iter.next()) |elem| {
        sum_x = try sum_x.add(elem);
    }
    var x_2_iter = x_2.iterator();
    while (x_2_iter.next()) |elem| {
        sum_x = try sum_x.add(elem);
    }
    std.log.info("Sum: {}", .{sum_x});
}
