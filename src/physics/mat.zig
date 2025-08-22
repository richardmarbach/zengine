const std = @import("std");
const vec = @import("vec.zig");

pub fn MatMxN(comptime Scalar: type, M: comptime_int, N: comptime_int) type {
    std.debug.assert(M > 0 and N > 0);
    return struct {
        pub const rows = M;
        pub const cols = N;

        pub const RowVec = vec.Vec(Scalar, N);
        pub const ColVec = vec.Vec(Scalar, M);

        v: [rows]RowVec,

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

        pub const Transposed = MatMxN(Matrix.T, Matrix.cols, Matrix.rows);

        pub inline fn transpose(m: *const Matrix) Transposed {
            var vs: [Transposed.rows]Transposed.RowVec = undefined;

            inline for (0..Matrix.rows) |r| {
                inline for (0..Matrix.cols) |c| {
                    vs[c].v[r] = m.v[r].v[c];
                }
            }

            return .{ .v = vs };
        }

        pub inline fn mul(a: *const Matrix, b: *const Matrix) Matrix {
            @setEvalBranchQuota(10000);
            var result: Matrix = undefined;
            inline for (0..Matrix.rows) |r| {
                inline for (0..Matrix.cols) |col| {
                    var sum: RowVec.T = 0.0;
                    inline for (0..RowVec.n) |i| {
                        // Note: we directly access rows/columns below as it is much faster **in
                        // debug builds**, instead of using these helpers:
                        //
                        // sum += a.row(r).mul(&b.col(col)).v[i];
                        sum += a.v[i].v[r] * b.v[col].v[i];
                    }
                    result.v[col].v[r] = sum;
                }
            }
            return result;
        }

        pub inline fn mulM(a: *const Matrix, b: anytype) t: {
            const MatrixB = @typeInfo(@TypeOf(b)).pointer.child;
            break :t MatMxN(Matrix.T, Matrix.rows, MatrixB.cols);
        } {
            const MatrixB = @typeInfo(@TypeOf(b)).pointer.child;
            std.debug.assert(MatrixB.cols == Matrix.rows);
            const Result = MatMxN(Matrix.T, Matrix.rows, MatrixB.cols);

            @setEvalBranchQuota(10000);
            var result: Result = undefined;
            inline for (0..Matrix.rows) |r| {
                inline for (0..MatrixB.cols) |c| {
                    var sum: RowVec.T = 0.0;
                    inline for (0..RowVec.n) |i| {
                        sum += a.v[r].v[i] * b.v[i].v[c];
                    }
                    result.v[c].v[r] = sum;
                }
            }

            return result;
        }

        pub inline fn mulVec(matrix: *const Matrix, vector: *const ColVec) ColVec {
            var result = [_]ColVec.T{0} ** ColVec.n;
            inline for (0..Matrix.rows) |r| {
                inline for (0..ColVec.n) |i| {
                    result[i] += matrix.v[r].v[i] * vector.v[r];
                }
            }
            return ColVec{ .v = result };
        }

        pub inline fn eqlApprox(a: *const Matrix, b: *const Matrix, tolerance: ColVec.T) bool {
            inline for (0..Matrix.rows) |r| {
                if (!ColVec.eqlApprox(&a.v[r], &b.v[r], tolerance)) {
                    return false;
                }
            }
            return true;
        }

        pub inline fn eql(a: *const Matrix, b: *const Matrix) bool {
            inline for (0..Matrix.rows) |r| {
                if (!ColVec.eql(&a.v[r], &b.v[r])) {
                    return false;
                }
            }
            return true;
        }

        pub inline fn format(self: Matrix, writer: *std.io.Writer) std.io.Writer.Error!void {
            try writer.print("{{", .{});
            inline for (0..rows) |r| {
                try writer.print("{f}", .{self.row(r)});
                if (r < rows - 1) {
                    try writer.print(", ", .{});
                }
            }
            try writer.print("}}", .{});
        }

        pub fn formatMultiLine(self: Matrix, writer: *std.io.Writer) std.io.Writer.Error!void {
            try writer.print("\n{{", .{});
            inline for (0..rows) |r| {
                if (r > 0) {
                    try writer.print(" ", .{});
                }
                try writer.print("{f}", .{self.row(r)});
                if (r < rows - 1) {
                    try writer.print(",\n", .{});
                }
            }
            try writer.print("}}", .{});
        }
    };
}
