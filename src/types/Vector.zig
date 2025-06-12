const std = @import("std");
const Rational = @import("Rational.zig").Rational;

pub const Vector = struct {
    allocator: std.mem.Allocator,
    components: []Rational,
    len: usize,

    /// Создаёт новый вектор заданной длины
    pub fn init(allocator: std.mem.Allocator, len: usize) !Vector {
        const components = try allocator.alloc(Rational, len);
        @memset(components, Rational.init(0, 1) catch unreachable);
        return Vector{
            .allocator = allocator,
            .components = components,
            .len = len,
        };
    }

    /// Создаёт вектор из переданных компонент (копирует данные)
    pub fn fromComponents(allocator: std.mem.Allocator, components: []const Rational) !Vector {
        const new_components = try allocator.alloc(Rational, components.len);
        for (components, 0..) |comp, i| {
            new_components[i] = try Rational.init(comp.numerator, comp.denominator);
        }
        return Vector{
            .allocator = allocator,
            .components = new_components,
            .len = components.len,
        };
    }

    /// Освобождает память вектора
    pub fn deinit(self: Vector) void {
        self.allocator.free(self.components);
    }

    /// Сложение векторов
    pub fn add(self: Vector, other: Vector) !Vector {
        if (self.len != other.len) return error.DimensionMismatch;
        var result = try Vector.init(self.allocator, self.len);
        errdefer result.deinit();

        for (self.components, other.components, 0..) |a, b, i| {
            result.components[i] = try a.add(b);
        }
        return result;
    }

    /// Вычитание векторов
    pub fn sub(self: Vector, other: Vector) !Vector {
        if (self.len != other.len) return error.DimensionMismatch;
        var result = try Vector.init(self.allocator, self.len);
        errdefer result.deinit();

        for (self.components, other.components, 0..) |a, b, i| {
            result.components[i] = try a.sub(b);
        }
        return result;
    }

    /// Умножение на скаляр
    pub fn scalarMul(self: Vector, scalar: Rational) !Vector {
        var result = try Vector.init(self.allocator, self.len);
        errdefer result.deinit();

        for (self.components, 0..) |comp, i| {
            result.components[i] = try comp.mul(scalar);
        }
        return result;
    }

    /// Скалярное произведение
    pub fn dot(self: Vector, other: Vector) !Rational {
        if (self.len != other.len) return error.DimensionMismatch;
        var sum = try Rational.init(0, 1);

        for (self.components, other.components) |a, b| {
            const product = try a.mul(b);
            sum = try sum.add(product);
        }
        return sum;
    }

    /// Проверка на равенство
    pub fn equals(self: Vector, other: Vector) bool {
        if (self.len != other.len) return false;
        for (self.components, other.components) |a, b| {
            if (!a.equals(b)) return false;
        }
        return true;
    }

    /// Нормализация вектора (создаёт единичный вектор)
    pub fn normalize(self: Vector) !Vector {
        const norm_squared = try self.dot(self);
        if (norm_squared.numerator == 0) return error.ZeroVector;

        const inv_norm = try Rational.init(norm_squared.denominator, norm_squared.numerator);
        const inv_norm_sqrt = try inv_norm.sqrtApprox(1000); // Нужно реализовать sqrtApprox в Rational

        return self.scalarMul(inv_norm_sqrt);
    }

    /// Итератор по компонентам вектора
    pub const Iterator = struct {
        index: usize = 0,
        vector: *const Vector,

        pub fn next(self: *Iterator) ?Rational {
            if (self.index >= self.vector.len) return null;
            defer self.index += 1;
            return self.vector.components[self.index];
        }

        pub fn reset(self: *Iterator) void {
            self.index = 0;
        }
    };

    /// Возвращает итератор для последовательного доступа к компонентам
    pub fn iterator(self: *const Vector) Iterator {
        return Iterator{ .vector = self };
    }

    /// Итератор с возможностью модификации компонент
    pub const MutIterator = struct {
        index: usize = 0,
        vector: *Vector,

        pub fn next(self: *MutIterator) ?*Rational {
            if (self.index >= self.vector.len) return null;
            defer self.index += 1;
            return &self.vector.components[self.index];
        }

        pub fn reset(self: *MutIterator) void {
            self.index = 0;
        }
    };

    /// Возвращает изменяемый итератор
    pub fn mutIterator(self: *Vector) MutIterator {
        return MutIterator{ .vector = self };
    }

    /// Сравнение векторов на равенство
    pub fn eql(self: Vector, other: Vector) bool {
        if (self.len != other.len) return false;
        for (self.components, other.components) |a, b| {
            if (!a.equals(b)) return false;
        }
        return true;
    }

    /// Лексикографическое сравнение
    pub fn lexCmp(self: Vector, other: Vector) !std.math.Order {
        if (self.len != other.len) return error.DimensionMismatch;

        for (self.components, other.components) |a, b| {
            const order = try a.order(b);
            if (order != .eq) return order;
        }
        return .eq;
    }

    /// Сравнение по норме (длине)
    pub fn normCmp(self: Vector, other: Vector) !std.math.Order {
        // Вычисляем квадраты норм (чтобы избежать вычисления квадратных корней)
        const self_norm_sq = try self.dot(self);
        const other_norm_sq = try other.dot(other);
        return try self_norm_sq.order(other_norm_sq);
    }
    /// Форматирование для печати
    pub fn format(
        self: Vector,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.writeAll("[");
        for (self.components, 0..) |comp, i| {
            if (i != 0) try writer.writeAll(", ");
            try comp.format("", .{}, writer);
        }
        try writer.writeAll("]");
    }
};

// Тесты
test "Vector basic operations" {
    const allocator = std.testing.allocator;

    // Создание векторов
    const v1 = try Vector.fromComponents(allocator, &[_]Rational{
        try Rational.init(1, 2),
        try Rational.init(3, 4),
    });
    defer v1.deinit();

    const v2 = try Vector.fromComponents(allocator, &[_]Rational{
        try Rational.init(1, 3),
        try Rational.init(2, 5),
    });
    defer v2.deinit();

    // Сложение
    const sum = try v1.add(v2);
    defer sum.deinit();
    try std.testing.expectEqual(sum.components[0], try Rational.init(5, 6));
    try std.testing.expectEqual(sum.components[1], try Rational.init(23, 20));

    // Скалярное произведение
    const dot = try v1.dot(v2);
    const x = try Rational.init(1 * 1, 2 * 3);
    const y = try Rational.init(3 * 2, 4 * 5);
    const s = try x.add(y);
    try std.testing.expectEqual(dot, s);
}

test "Vector errors" {
    const allocator = std.testing.allocator;

    const v1 = try Vector.init(allocator, 2);
    defer v1.deinit();

    const v2 = try Vector.init(allocator, 3);
    defer v2.deinit();

    // Проверка несовпадения размеров
    try std.testing.expectError(error.DimensionMismatch, v1.add(v2));
    try std.testing.expectError(error.DimensionMismatch, v1.dot(v2));
}

// Пример использования итераторов
test "Vector iterators" {
    const allocator = std.testing.allocator;

    var vec = try Vector.fromComponents(allocator, &[_]Rational{
        try Rational.init(1, 2),
        try Rational.init(3, 4),
        try Rational.init(5, 6),
    });
    defer vec.deinit();

    // Итерация с доступом только для чтения
    var iter = vec.iterator();
    try std.testing.expectEqual(try Rational.init(1, 2), iter.next().?);
    try std.testing.expectEqual(try Rational.init(3, 4), iter.next().?);
    try std.testing.expectEqual(try Rational.init(5, 6), iter.next().?);
    try std.testing.expect(iter.next() == null);

    // Изменяемый итератор
    var mut_iter = vec.mutIterator();
    while (mut_iter.next()) |comp| {
        comp.* = try comp.add(try Rational.init(1, 1));
    }
    try std.testing.expectEqual(vec.components[0], try Rational.init(3, 2));
}

// Обновлённые тесты для сравнения векторов
test "Vector comparison" {
    const allocator = std.testing.allocator;

    // Векторы для тестирования
    const v1 = try Vector.fromComponents(allocator, &[_]Rational{
        try Rational.init(3, 1), // Большая норма
        try Rational.init(4, 1),
    });
    defer v1.deinit();

    const v2 = try Vector.fromComponents(allocator, &[_]Rational{
        try Rational.init(1, 1), // Меньшая норма
        try Rational.init(1, 1),
    });
    defer v2.deinit();

    const v3 = try Vector.fromComponents(allocator, &[_]Rational{
        try Rational.init(3, 1), // Такая же норма как v1
        try Rational.init(4, 1),
    });
    defer v3.deinit();

    // Проверка сравнения по норме
    try std.testing.expect(try v1.normCmp(v2) == .gt); // √(3²+4²) > √(1²+1²)
    try std.testing.expect(try v2.normCmp(v1) == .lt); // Обратное сравнение
    try std.testing.expect(try v1.normCmp(v3) == .eq); // Нормы равны

    // Проверка лексикографического сравнения
    try std.testing.expect(try v1.lexCmp(v2) == .gt); // Первые компоненты 3 > 1
    try std.testing.expect(try v2.lexCmp(v1) == .lt);

    // Проверка равенства
    try std.testing.expect(v1.eql(v3));
    try std.testing.expect(!v1.eql(v2));
}
