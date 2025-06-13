const std = @import("std");
const Rational = @import("Rational.zig").Rational;
const Vector = @import("Vector.zig").Vector;

pub const Matrix = struct {
    allocator: std.mem.Allocator,
    rows: []Vector,
    rows_count: usize,
    cols_count: usize,

    /// Создаёт матрицу заданного размера, заполненную нулями
    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !Matrix {
        const rows_vec = try allocator.alloc(Vector, rows);
        errdefer allocator.free(rows_vec);

        for (rows_vec) |*row| {
            row.* = try Vector.init(allocator, cols);
        }

        return Matrix{
            .allocator = allocator,
            .rows = rows_vec,
            .rows_count = rows,
            .cols_count = cols,
        };
    }

    /// Освобождает память матрицы
    pub fn deinit(self: Matrix) void {
        for (self.rows) |row| {
            row.deinit();
        }
        self.allocator.free(self.rows);
    }

    /// Доступ к элементу (i, j) с проверкой границ
    pub fn at(self: Matrix, i: usize, j: usize) !Rational {
        if (i >= self.rows_count or j >= self.cols_count) {
            return error.IndexOutOfBounds;
        }
        return try self.rows[i].at(j);
    }

    /// Доступ к элементу (i, j) с возможностью изменения
    pub fn atMut(self: *Matrix, i: usize, j: usize) !*Rational {
        if (i >= self.rows_count or j >= self.cols_count) {
            return error.IndexOutOfBounds;
        }
        return try self.rows[i].atMut(j);
    }

    /// Умножение матрицы на вектор (исправленная версия)
    pub fn mulVector(self: Matrix, vec: Vector) !Vector {
        if (self.cols_count != vec.len) {
            return error.DimensionMismatch;
        }

        var result = try Vector.init(self.allocator, self.rows_count);
        errdefer result.deinit();

        for (self.rows, 0..) |row, i| {
            const dot = try row.dot(vec);
            (try result.atMut(i)).* = dot; // Прямое присваивание вместо copyFrom
        }

        return result;
    }

    /// Умножение матриц (исправленная версия)
    pub fn mulMatrix(self: Matrix, other: Matrix) !Matrix {
        if (self.cols_count != other.rows_count) {
            return error.DimensionMismatch;
        }

        var result = try Matrix.init(self.allocator, self.rows_count, other.cols_count);
        errdefer result.deinit();

        for (result.rows, 0..) |*row, i| {
            for (0..other.cols_count) |j| {
                var sum = try Rational.init(0, 1);
                for (0..self.cols_count) |k| {
                    const a = try self.at(i, k);
                    const b = try other.at(k, j);
                    sum = try sum.add(try a.mul(b));
                }
                (try row.atMut(j)).* = sum; // Прямое присваивание
            }
        }

        return result;
    }

    /// Транспонирование матрицы (исправленная версия)
    pub fn transpose(self: Matrix) !Matrix {
        var result = try Matrix.init(self.allocator, self.cols_count, self.rows_count);
        errdefer result.deinit();

        for (self.rows, 0..) |row, i| {
            for (0..self.cols_count) |j| {
                const val = try row.at(j);
                (try result.atMut(j, i)).* = val; // Прямое присваивание
            }
        }

        return result;
    }

    /// Форматирование для печати
    pub fn format(
        self: Matrix,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.writeAll("[\n");
        for (self.rows) |row| {
            try writer.writeAll("  ");
            try row.format("", .{}, writer);
            try writer.writeAll(",\n");
        }
        try writer.writeAll("]");
    }
    /// Вычисляет определитель матрицы
    pub fn determinant(self: Matrix) !Rational {
        if (self.rows_count != self.cols_count) {
            return error.NotSquareMatrix;
        }

        // Создаем копию матрицы для преобразований
        var mat = try self.clone();
        defer mat.deinit();

        var det = try Rational.init(1, 1);
        var sign = try Rational.init(1, 1);

        for (0..mat.rows_count) |k| {
            // Поиск ведущего элемента (pivot)
            var pivot_row = k;
            var pivot_val = try mat.at(k, k);

            for (k + 1..mat.rows_count) |i| {
                const current = try mat.at(i, k);
                if (try current.order(pivot_val) == .gt) {
                    pivot_row = i;
                    pivot_val = current;
                }
            }

            // Если ведущий элемент нулевой - матрица вырождена
            if (pivot_val.numerator == 0) {
                return Rational.init(0, 1);
            }

            // Перестановка строк
            if (pivot_row != k) {
                try mat.swapRows(k, pivot_row);
                sign = try sign.negate();
            }

            // Приведение к треугольному виду
            for (k + 1..mat.rows_count) |i| {
                const factor = try (try mat.at(i, k)).div(try mat.at(k, k));

                for (k..mat.rows_count) |j| {
                    const product = try (try mat.at(k, j)).mul(factor);
                    const new_val = try (try mat.at(i, j)).sub(product);
                    (try mat.atMut(i, j)).* = new_val;
                }
            }

            // Умножаем определитель на диагональный элемент
            det = try det.mul(try mat.at(k, k));
        }

        return try det.mul(sign);
    }

    /// Создает копию матрицы
    fn clone(self: Matrix) !Matrix {
        var copy = try Matrix.init(self.allocator, self.rows_count, self.cols_count);
        errdefer copy.deinit();

        for (self.rows, 0..) |row, i| {
            for (0..self.cols_count) |j| {
                (try copy.atMut(i, j)).* = try row.at(j);
            }
        }

        return copy;
    }

    /// Меняет местами две строки матрицы
    fn swapRows(self: *Matrix, i: usize, j: usize) !void {
        if (i >= self.rows_count or j >= self.rows_count) {
            return error.IndexOutOfBounds;
        }

        const tmp = self.rows[i];
        self.rows[i] = self.rows[j];
        self.rows[j] = tmp;
    }
    /// Решает СЛАУ вида Ax = b
    /// Возвращает вектор x
    pub fn solve(self: Matrix, b: Vector) !Vector {
        if (self.rows_count != self.cols_count) {
            return error.NotSquareMatrix;
        }
        if (self.rows_count != b.len) {
            return error.DimensionMismatch;
        }

        // Создаем расширенную матрицу [A|b]
        var augmented = try self.augment(b);
        defer augmented.deinit();

        // Прямой ход метода Гаусса
        try augmented.forwardElimination();

        // Обратный ход метода Гаусса
        return try augmented.backSubstitution();
    }

    /// Создает расширенную матрицу [A|b]
    fn augment(self: Matrix, b: Vector) !Matrix {
        var aug = try Matrix.init(self.allocator, self.rows_count, self.cols_count + 1);
        errdefer aug.deinit();

        for (self.rows, 0..) |row, i| {
            for (0..self.cols_count) |j| {
                (try aug.atMut(i, j)).* = try row.at(j);
            }
            (try aug.atMut(i, self.cols_count)).* = try b.at(i);
        }

        return aug;
    }

    /// Прямой ход метода Гаусса (приведение к ступенчатому виду)
    fn forwardElimination(self: *Matrix) !void {
        for (0..self.rows_count) |k| {
            // Поиск ведущего элемента
            var pivot_row = k;
            var pivot_val = try self.at(k, k);

            for (k + 1..self.rows_count) |i| {
                const current = try self.at(i, k);
                if (try current.order(pivot_val) == .gt) {
                    pivot_row = i;
                    pivot_val = current;
                }
            }

            // Перестановка строк
            if (pivot_row != k) {
                try self.swapRows(k, pivot_row);
            }

            // Нормализация текущей строки
            const pivot = try self.at(k, k);
            if (pivot.numerator == 0) {
                return error.SingularMatrix;
            }

            for (k..self.cols_count) |j| {
                const val = try self.at(k, j);
                (try self.atMut(k, j)).* = try val.div(pivot);
            }

            // Исключение переменной из нижележащих строк
            for (k + 1..self.rows_count) |i| {
                const factor = try self.at(i, k);

                for (k..self.cols_count) |j| {
                    const product = try (try self.at(k, j)).mul(factor);
                    const new_val = try (try self.at(i, j)).sub(product);
                    (try self.atMut(i, j)).* = new_val;
                }
            }
        }
    }

    /// Обратный ход метода Гаусса
    fn backSubstitution(self: Matrix) !Vector {
        var x = try Vector.init(self.allocator, self.rows_count);
        errdefer x.deinit();

        const n = self.rows_count;

        for (0..n) |i| {
            const idx = n - 1 - i; // Идем с последней строки
            var sum = try Rational.init(0, 1);

            for (idx + 1..n) |j| {
                const a = try self.at(idx, j);
                const x_j = try x.at(j);
                sum = try sum.add(try a.mul(x_j));
            }

            const b = try self.at(idx, n);
            const x_val = try b.sub(sum);
            (try x.atMut(idx)).* = x_val;
        }

        return x;
    }
};
test "Matrix operations" {
    const allocator = std.testing.allocator;

    // Создаём матрицу 2x3
    var mat = try Matrix.init(allocator, 2, 3);
    defer mat.deinit();

    // Заполняем значениями (исправленная версия)
    (try mat.atMut(0, 0)).* = try Rational.init(1, 1);
    (try mat.atMut(0, 1)).* = try Rational.init(2, 1);
    (try mat.atMut(0, 2)).* = try Rational.init(3, 1);
    (try mat.atMut(1, 0)).* = try Rational.init(4, 1);
    (try mat.atMut(1, 1)).* = try Rational.init(5, 1);
    (try mat.atMut(1, 2)).* = try Rational.init(6, 1);

    // Создаём вектор
    const vec = try Vector.fromRationalComponents(allocator, &[_]Rational{
        try Rational.init(1, 1),
        try Rational.init(0, 1),
        try Rational.init(2, 1),
    });
    defer vec.deinit();

    // Умножение матрицы на вектор
    const result = try mat.mulVector(vec);
    defer result.deinit();

    // Проверка результата
    try std.testing.expectEqual(try result.at(0), try Rational.init(7, 1));
    try std.testing.expectEqual(try result.at(1), try Rational.init(16, 1));
}
test "Matrix determinant" {
    const allocator = std.testing.allocator;

    // Создаем матрицу 3x3
    var mat = try Matrix.init(allocator, 3, 3);
    defer mat.deinit();

    // Заполняем значениями
    (try mat.atMut(0, 0)).* = try Rational.init(2, 1);
    (try mat.atMut(0, 1)).* = try Rational.init(-3, 1);
    (try mat.atMut(0, 2)).* = try Rational.init(1, 1);

    (try mat.atMut(1, 0)).* = try Rational.init(2, 1);
    (try mat.atMut(1, 1)).* = try Rational.init(0, 1);
    (try mat.atMut(1, 2)).* = try Rational.init(-1, 1);

    (try mat.atMut(2, 0)).* = try Rational.init(1, 1);
    (try mat.atMut(2, 1)).* = try Rational.init(4, 1);
    (try mat.atMut(2, 2)).* = try Rational.init(5, 1);

    // Вычисляем определитель
    const det = try mat.determinant();

    // Проверяем результат (ожидается 49)
    try std.testing.expectEqual(det, try Rational.init(49, 1));
}
test "Gaussian elimination" {
    const allocator = std.testing.allocator;

    // Создаем матрицу коэффициентов 3x3
    var A = try Matrix.init(allocator, 3, 3);
    defer A.deinit();

    // Заполняем матрицу
    (try A.atMut(0, 0)).* = try Rational.init(2, 1);
    (try A.atMut(0, 1)).* = try Rational.init(1, 1);
    (try A.atMut(0, 2)).* = try Rational.init(-1, 1);

    (try A.atMut(1, 0)).* = try Rational.init(-3, 1);
    (try A.atMut(1, 1)).* = try Rational.init(-1, 1);
    (try A.atMut(1, 2)).* = try Rational.init(2, 1);

    (try A.atMut(2, 0)).* = try Rational.init(-2, 1);
    (try A.atMut(2, 1)).* = try Rational.init(1, 1);
    (try A.atMut(2, 2)).* = try Rational.init(2, 1);

    // Вектор правых частей
    const b = try Vector.fromRationalComponents(allocator, &[_]Rational{ try Rational.init(8, 1), try Rational.init(-11, 1), try Rational.init(-3, 1) });
    defer b.deinit();

    // Решаем систему
    const x = try A.solve(b);
    defer x.deinit();

    // Проверяем решение (ожидается x = [2, 3, -1])
    try std.testing.expectEqual(try x.at(0), try Rational.init(2, 1));
    try std.testing.expectEqual(try x.at(1), try Rational.init(3, 1));
    try std.testing.expectEqual(try x.at(2), try Rational.init(-1, 1));
}
