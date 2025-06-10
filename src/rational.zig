const std = @import("std");
// const math = std.math;
// const Allocator = std.mem.Allocator;

pub const Rational = struct {
    numerator: i64,
    denominator: i64, // всегда > 0

    /// Создаёт дробь, сокращает её и проверяет переполнение
    pub fn init(numerator: i64, denominator: i64) !Rational {
        if (denominator == 0) return error.DivisionByZero;
        if (denominator < 0) {
            return Rational.init(-numerator, -denominator);
        }

        var r = Rational{ .numerator = numerator, .denominator = denominator };
        r.normalize();
        return r;
    }

    /// Сокращает дробь (НОД)
    pub fn normalize(self: *Rational) void {
        const gcd_val = gcd(@as(i64, @intCast(@abs(self.numerator))), @as(i64, @intCast(@abs(self.denominator))));
        self.numerator = @divExact(self.numerator, gcd_val);
        self.denominator = @divExact(self.denominator, gcd_val);
    }

    /// НОД (алгоритм Евклида)
    fn gcd(a: i64, b: i64) i64 {
        var x = a;
        var y = b;
        while (y != 0) {
            const tmp = y;
            y = @mod(x, y);
            x = tmp;
        }
        return x;
    }

    /// Проверяет переполнение умножения
    fn safeMul(a: i64, b: i64) !i64 {
        const res = a *% b; // умножение с переполнением
        if (a != 0) {
            const divisor = @divTrunc(res, a);
            const rem = @rem(res, a);
            if (divisor != b or rem != 0) return error.Overflow;
        }
        return res;
    }

    /// Проверяет переполнение сложения
    fn safeAdd(a: i64, b: i64) !i64 {
        const res = a +% b; // сложение с переполнением
        if ((b > 0 and res < a) or (b < 0 and res > a)) return error.Overflow;
        return res;
    }

    /// Сложение (+)
    pub fn add(a: Rational, b: Rational) !Rational {
        const new_den = try safeMul(a.denominator, b.denominator);
        const num1 = try safeMul(a.numerator, b.denominator);
        const num2 = try safeMul(b.numerator, a.denominator);
        const new_num = try safeAdd(num1, num2);
        return Rational.init(new_num, new_den);
    }

    /// Вычитание (-)
    pub fn sub(a: Rational, b: Rational) !Rational {
        const neg_b = try b.negate();
        return a.add(neg_b);
    }

    /// Умножение (*)
    pub fn mul(a: Rational, b: Rational) !Rational {
        const new_num = try safeMul(a.numerator, b.numerator);
        const new_den = try safeMul(a.denominator, b.denominator);
        return Rational.init(new_num, new_den);
    }

    /// Деление (/)
    pub fn div(a: Rational, b: Rational) !Rational {
        if (b.numerator == 0) return error.DivisionByZero;
        const reciprocal = try Rational.init(b.denominator, b.numerator);
        return a.mul(reciprocal);
    }

    /// Отрицание (-x)
    pub fn negate(self: Rational) !Rational {
        return Rational.init(-self.numerator, self.denominator);
    }

    /// Модуль (|x|)
    pub fn abs(self: Rational) Rational {
        return Rational.init(@as(i64, @intCast(@abs(self.numerator))), self.denominator) catch unreachable;
    }

    /// Сравнение (==)
    pub fn equals(a: Rational, b: Rational) bool {
        return a.numerator == b.numerator and a.denominator == b.denominator;
    }

    /// Сравнение (<, >, <=, >=)
    pub fn order(a: Rational, b: Rational) !std.math.Order {
        const lhs = try safeMul(a.numerator, b.denominator);
        const rhs = try safeMul(b.numerator, a.denominator);
        return std.math.order(lhs, rhs);
    }

    /// Преобразует в f64
    pub fn toFloat(self: Rational) f64 {
        return @as(f64, @floatFromInt(self.numerator)) / @as(f64, @floatFromInt(self.denominator));
    }

    /// Форматирование для печати (например, `print("{}", .{rational})`)
    pub fn format(
        self: Rational,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d}/{d}", .{ self.numerator, self.denominator });
    }
};
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

test "Rational.init: сокращение дроби" {
    const r = try Rational.init(2, 4);
    try expectEqual(r.numerator, 1);
    try expectEqual(r.denominator, 2);
}

test "Rational.init: отрицательный знаменатель" {
    const r = try Rational.init(3, -4);
    try expectEqual(r.numerator, -3);
    try expectEqual(r.denominator, 4);
}

test "Rational.init: деление на ноль" {
    try expectError(error.DivisionByZero, Rational.init(1, 0));
}

test "Rational.add: сложение дробей" {
    const a = try Rational.init(1, 2);
    const b = try Rational.init(1, 3);
    const sum = try a.add(b);
    try expectEqual(sum.numerator, 5);
    try expectEqual(sum.denominator, 6);
}

test "Rational.sub: вычитание дробей" {
    const a = try Rational.init(1, 2);
    const b = try Rational.init(1, 4);
    const diff = try a.sub(b);
    try expectEqual(diff.numerator, 1);
    try expectEqual(diff.denominator, 4);
}

test "Rational.mul: умножение дробей" {
    const a = try Rational.init(2, 3);
    const b = try Rational.init(3, 4);
    const product = try a.mul(b);
    try expectEqual(product.numerator, 1);
    try expectEqual(product.denominator, 2);
}

test "Rational.div: деление дробей" {
    const a = try Rational.init(1, 2);
    const b = try Rational.init(3, 4);
    const quotient = try a.div(b);
    try expectEqual(quotient.numerator, 2);
    try expectEqual(quotient.denominator, 3);
}

test "Rational.div: деление на ноль" {
    const a = try Rational.init(1, 2);
    const b = try Rational.init(0, 1);
    try expectError(error.DivisionByZero, a.div(b));
}

test "Rational.negate: отрицание" {
    const r = try Rational.init(3, 4);
    const neg = try r.negate();
    try expectEqual(neg.numerator, -3);
    try expectEqual(neg.denominator, 4);
}

test "Rational.abs: модуль" {
    const r1 = try Rational.init(-3, 4);
    const r2 = try Rational.init(3, -4);
    const abs1 = r1.abs();
    const abs2 = r2.abs();
    try expectEqual(abs1.numerator, 3);
    try expectEqual(abs1.denominator, 4);
    try expectEqual(abs2.numerator, 3);
    try expectEqual(abs2.denominator, 4);
}

test "Rational.equals: сравнение дробей" {
    const a = try Rational.init(1, 2);
    const b = try Rational.init(2, 4);
    const c = try Rational.init(1, 3);
    try expect(a.equals(b));
    try expect(!a.equals(c));
}

test "Rational.order: упорядочивание дробей" {
    const a = try Rational.init(1, 2);
    const b = try Rational.init(1, 3);
    const c = try Rational.init(2, 4);
    try expect(try a.order(b) == .gt); // 1/2 > 1/3
    try expect(try b.order(a) == .lt); // 1/3 < 1/2
    try expect(try a.order(c) == .eq); // 1/2 == 2/4
}

test "Rational.toFloat: преобразование в float" {
    const r = try Rational.init(1, 2);
    try expect(r.toFloat() == 0.5);
}

test "Rational.safeMul: переполнение умножения" {
    try expectError(error.Overflow, Rational.safeMul(std.math.maxInt(i64), 2));
}

test "Rational.safeAdd: переполнение сложения" {
    try expectError(error.Overflow, Rational.safeAdd(std.math.maxInt(i64), 1));
}
