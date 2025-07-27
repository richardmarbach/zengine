const std = @import("std");
const vec = @import("vec.zig");

pub fn MatMxN(comptime Scalar: type, M: comptime_int, N: comptime_int) type {
    std.debug.assert(M > 0 and N > 0);
    return struct {
        pub const rows = M;
        pub const cols = N;

        pub const RowVec = vec.Vec(Scalar, N);
        pub const ColVec = vec.Vec(Scalar, M);

        v: [cols]RowVec,

        pub const T = Scalar;
        pub const Matrix = @This();

        pub fn init(vs: [rows][cols]Scalar) Matrix {
            var v: [rows]RowVec = undefined;
            inline for (0..rows) |r| {
                inline for (0..cols) |c| {
                    v[r].v[c] = vs[r][c];
                }
            }
            return .{ .v = v };
        }

        pub inline fn row(m: *const Matrix, r: usize) RowVec {
            var v: [N]Scalar = undefined;
            inline for (0..N) |i| {
                v[i] = m.v[r].v[i];
            }
            return .{ .v = v };
        }

        pub inline fn zero() Matrix {
            var v: [rows]RowVec = undefined;
            inline for (0..rows) |r| {
                inline for (0..cols) |c| {
                    v[r].v[c] = 0.0;
                }
            }
            return .{ .v = v };
        }

        // pub inline fn transpose(m: *const Matrix) Matrix {
        //
        // }

        const Shared = MatShared(RowVec, ColVec, Matrix);

        pub const mul = Shared.mul;
        pub const mulVec = Shared.mulVec;
        pub const eql = Shared.eql;
        pub const eqlApprox = Shared.eqlApprox;
        pub const format = Shared.format;
    };
}

pub fn MatShared(comptime RowVec: type, comptime ColVec: type, comptime Matrix: type) type {
    return struct {
        pub inline fn mul(a: *const Matrix, b: *const Matrix) Matrix {
            @setEvalBranchQuota(10000);
            var result: Matrix = undefined;
            inline for (0..Matrix.rows) |row| {
                inline for (0..Matrix.cols) |col| {
                    var sum: RowVec.T = 0.0;
                    inline for (0..RowVec.n) |i| {
                        // Note: we directly access rows/columns below as it is much faster **in
                        // debug builds**, instead of using these helpers:
                        //
                        // sum += a.row(row).mul(&b.col(col)).v[i];
                        sum += a.v[i].v[row] * b.v[col].v[i];
                    }
                    result.v[col].v[row] = sum;
                }
            }
            return result;
        }

        pub inline fn mulVec(matrix: *const Matrix, vector: *const ColVec) ColVec {
            var result = [_]ColVec.T{0} ** ColVec.n;
            inline for (0..Matrix.rows) |row| {
                inline for (0..ColVec.n) |i| {
                    result[i] += matrix.v[row].v[i] * vector.v[row];
                }
            }
            return ColVec{ .v = result };
        }

        pub inline fn eqlApprox(a: *const Matrix, b: *const Matrix, tolerance: ColVec.T) bool {
            inline for (0..Matrix.rows) |row| {
                if (!ColVec.eqlApprox(&a.v[row], &b.v[row], tolerance)) {
                    return false;
                }
            }
            return true;
        }

        pub inline fn eql(a: *const Matrix, b: *const Matrix) bool {
            inline for (0..Matrix.rows) |row| {
                if (!ColVec.eql(&a.v[row], &b.v[row])) {
                    return false;
                }
            }
            return true;
        }

        pub inline fn format(
            self: Matrix,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) @TypeOf(writer).Error!void {
            const rows = @TypeOf(self).rows;
            try writer.print("{{", .{});
            inline for (0..rows) |r| {
                try std.fmt.formatType(self.row(r), fmt, options, writer, 1);
                if (r < rows - 1) {
                    try writer.print(", ", .{});
                }
            }
            try writer.print("}}", .{});
        }
    };
}
