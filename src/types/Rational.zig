const std = @import("std");

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
    fn gcd_evklid(a: i64, b: i64) i64 {
        var x = a;
        var y = b;
        while (y != 0) {
            const tmp = y;
            y = @mod(x, y);
            x = tmp;
        }
        return x;
    }
    /// Оптимизированный НОД (бинарный алгоритм)
    fn gcd(a: i64, b: i64) i64 {
        // Быстрая проверка на нули
        if (a == 0) return @intCast(@abs(b));
        if (b == 0) return @intCast(@abs(a));

        var x: i64 = @intCast(@abs(a));
        var y: i64 = @intCast(@abs(b));

        // Находим общую степень 2
        const common_tz = @min(@ctz(x), @ctz(y));
        const shift = @as(u6, @intCast(@min(common_tz, 63)));

        // Нормализуем, убирая общие множители 2
        x >>= @as(u6, @intCast(@ctz(x)));
        y >>= @as(u6, @intCast(@ctz(y)));

        // Основной цикл
        while (x != y) {
            if (x > y) {
                x -= y;
                x >>= @as(u6, @intCast(@ctz(x)));
            } else {
                y -= x;
                y >>= @as(u6, @intCast(@ctz(y)));
            }
        }

        // Безопасный сдвиг с проверкой
        return if (shift > 0) x << @as(u6, @intCast(shift)) else x;
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
    /// Преобразует число с плавающей запятой в Rational с заданной точностью
    /// Использует алгоритм цепных дробей для нахождения наилучшего приближения
    /// max_denominator - максимально допустимый знаменатель (точность аппроксимации)
    pub fn fromFloat(float: anytype, max_denominator: u32) !Rational {
        const T = @TypeOf(float);
        // Проверка типа и обработка comptime_float
        switch (T) {
            f32, f64 => {},
            comptime_float => {
                // Для comptime_float конвертируем в f64
                return fromFloat(@as(f64, float), max_denominator);
            },
            else => @compileError("fromFloat supports only f32, f64 and comptime_float, found " ++ @typeName(T)),
        }

        // Обработка специальных случаев
        if (std.math.isNan(float)) return error.InvalidNumber;
        if (std.math.isInf(float)) return error.InfiniteNumber;

        const is_negative = float < 0;
        const x = if (is_negative) -float else float;

        // Особые случаи для 0 и целых чисел
        if (x == 0) return Rational.init(0, 1);
        // Проверка на целое число, которое помещается в i64
        if (@floor(x) == x) {
            if (x <= std.math.maxInt(i64)) {
                return Rational.init(if (is_negative) -@as(i64, @intFromFloat(x)) else @as(i64, @intFromFloat(x)), 1);
            }
            return error.Overflow;
        }

        // Алгоритм цепных дробей
        var m0: u32 = 0; // Предыдущий числитель
        var m1: u32 = 1; // Текущий числитель
        var n0: u32 = 1; // Предыдущий знаменатель
        var n1: u32 = 0; // Текущий знаменатель
        var best_num: u32 = 0; // Лучший числитель
        var best_den: u32 = 1; // Лучший знаменатель
        var best_err = x; // Лучшая погрешность

        var current_x = x;
        while (true) {
            const a = @as(u32, @intFromFloat(current_x)); // Целая часть
            const m2 = m0 + a * m1; // Новый числитель
            const n2 = n0 + a * n1; // Новый знаменатель

            // Проверка на превышение максимального знаменателя
            if (n2 > max_denominator) break;

            // Вычисление приближения и погрешности
            const approx = @as(f64, @floatFromInt(m2)) / @as(f64, @floatFromInt(n2));
            const err = @abs(approx - x);

            // Обновление лучшего приближения
            if (err < best_err) {
                best_err = err;
                best_num = m2;
                best_den = n2;
            }

            // Сдвиг значений для следующей итерации
            m0 = m1;
            n0 = n1;
            m1 = m2;
            n1 = n2;

            // Проверка на завершение
            const frac_part = current_x - @as(f64, @floatFromInt(a));
            if (frac_part == 0) break;
            current_x = 1 / frac_part;
        }

        return Rational.init(if (is_negative) -@as(i64, best_num) else @as(i64, best_num), @as(i64, best_den));
    }
    /// Из целого числа
    pub fn fromInt(value: anytype) !Rational {
        const T = @TypeOf(value);
        comptime switch (T) {
            i32, i64, u32, u64, comptime_int => {},
            else => @compileError("fromInt supports only integer types, found " ++ @typeName(T)),
        };
        return Rational.init(value, 1);
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

        const abs_num = if (self.numerator < 0) @as(i64, -self.numerator) else self.numerator;
        const whole_part = @divTrunc(abs_num, self.denominator);
        const remainder = @mod(abs_num, self.denominator);

        // Выводим знак
        if (self.numerator < 0) {
            try writer.writeAll("-");
        }

        // Если есть целая часть
        if (whole_part != 0) {
            try writer.print("{}", .{whole_part});

            // Если есть и дробная часть
            if (remainder != 0) {
                try writer.writeAll(" ");
                try writer.print("{d}/{d}", .{ remainder, self.denominator });
            }
        } else {
            // Только дробная часть или ноль
            if (remainder != 0) {
                try writer.print("{d}/{d}", .{ remainder, self.denominator });
            } else {
                try writer.writeAll("0");
            }
        }
    }
};
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

test "Rational.fromFloat: основные случаи" {
    const half = try Rational.fromFloat(0.5, 100);
    try expectEqual(half.numerator, 1);
    try expectEqual(half.denominator, 2);

    const third = try Rational.fromFloat(0.3333333333333333, 100);
    try expectEqual(third.numerator, 1);
    try expectEqual(third.denominator, 3);
}

test "Rational.fromFloat: специальные случаи" {
    try expectError(error.InvalidNumber, Rational.fromFloat(std.math.nan(f64), 100));
    try expectError(error.InfiniteNumber, Rational.fromFloat(std.math.inf(f64), 100));
    try expectError(error.Overflow, Rational.fromFloat(1e100, 1000));
}

test "Rational.fromFloat: simple" {
    const half = try Rational.fromFloat(0.5, 100);
    try expectEqual(half.numerator, 1);
    try expectEqual(half.denominator, 2);
}

test "Rational.fromFloat: π" {
    const pi = try Rational.fromFloat(3.141592653589793, 1000);
    try expectEqual(pi.numerator, 355);
    try expectEqual(pi.denominator, 113); // 355/113 ≈ 3.14159292035
}

test "Rational.fromFloat: negative" {
    const neg = try Rational.fromFloat(-2.5, 10);
    try expectEqual(neg.numerator, -5);
    try expectEqual(neg.denominator, 2);
}

test "Rational.fromFloat: special cases" {
    try expectError(error.InvalidNumber, Rational.fromFloat(std.math.nan(f64), 100));
    try expectError(error.InfiniteNumber, Rational.fromFloat(std.math.inf(f64), 100));
}
test "Rational.fromInt: из целого числа" {
    const r = try Rational.fromInt(7);
    try expectEqual(r.numerator, 7);
    try expectEqual(r.denominator, 1);
}

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

test "Rational formatting" {
    // Создаем буфер для тестирования вывода
    var buf: [32]u8 = undefined;

    // Тест 1: Положительное смешанное число
    const r1 = try Rational.init(7, 2);
    try std.testing.expectEqualStrings("3 1/2", try std.fmt.bufPrint(&buf, "{}", .{r1}));

    // Тест 2: Отрицательное смешанное число
    const r2 = try Rational.init(-5, 2);
    try std.testing.expectEqualStrings("-2 1/2", try std.fmt.bufPrint(&buf, "{}", .{r2}));

    // Тест 3: Только дробная часть
    const r3 = try Rational.init(1, 2);
    try std.testing.expectEqualStrings("1/2", try std.fmt.bufPrint(&buf, "{}", .{r3}));

    // Тест 4: Только целая часть
    const r4 = try Rational.init(4, 1);
    try std.testing.expectEqualStrings("4", try std.fmt.bufPrint(&buf, "{}", .{r4}));

    // Тест 5: Ноль
    const r5 = try Rational.init(0, 1);
    try std.testing.expectEqualStrings("0", try std.fmt.bufPrint(&buf, "{}", .{r5}));
}
