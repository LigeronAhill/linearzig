const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

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
        if (a != 0 and @divExact(res, a) != b) return error.Overflow;
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
        return Rational.init(math.absInt(self.numerator) catch unreachable, self.denominator) catch unreachable;
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
