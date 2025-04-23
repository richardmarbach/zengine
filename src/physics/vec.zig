const std = @import("std");

pub const VecComponent = enum { x, y, z };

pub fn Vec2(comptime Scalar: type) type {
    return struct {
        v: Vector,

        pub const n = 2;

        pub const T = Scalar;

        pub const Vector = @Vector(n, Scalar);

        const VecN = @This();

        const Shared = VecShared(Scalar, VecN);

        pub inline fn init(xs: Scalar, ys: Scalar) VecN {
            return .{ .v = .{ xs, ys } };
        }

        pub inline fn x(v: *const VecN) Scalar {
            return v.v[0];
        }

        pub inline fn y(v: *const VecN) Scalar {
            return v.v[1];
        }

        pub inline fn setX(v: *VecN, s: Scalar) void {
            v.v[0] = s;
        }

        pub inline fn setY(v: *VecN, s: Scalar) void {
            v.v[1] = s;
        }

        pub const add = Shared.add;
        pub const sub = Shared.sub;
        pub const mul = Shared.mul;
        pub const div = Shared.div;
        pub const addScalar = Shared.addScalar;
        pub const subScalar = Shared.subScalar;
        pub const mulScalar = Shared.mulScalar;
        pub const divScalar = Shared.divScalar;
        pub const less = Shared.less;
        pub const lessEq = Shared.lessEq;
        pub const greaterEq = Shared.greaterEq;
        pub const greater = Shared.greater;
        pub const len2 = Shared.len2;
        pub const len = Shared.len;
        pub const normalize = Shared.normalize;
        pub const dir = Shared.dir;
        pub const dist2 = Shared.dist2;
        pub const dist = Shared.dist;
        pub const dot = Shared.dot;
        pub const splat = Shared.splat;
        pub const eqlApprox = Shared.eqlApprox;
        pub const eql = Shared.eql;
        pub const format = Shared.format;
    };
}

pub fn Vec3(comptime Scalar: type) type {
    return struct {
        v: Vector,

        pub const n = 3;

        pub const T = Scalar;

        pub const Vector = @Vector(n, Scalar);

        const VecN = @This();

        const Shared = VecShared(Scalar, VecN);

        pub inline fn init(xs: Scalar, ys: Scalar, zs: Scalar) VecN {
            return .{ .v = .{ xs, ys, zs } };
        }

        pub inline fn x(v: *const VecN) Scalar {
            return v.v[0];
        }

        pub inline fn y(v: *const VecN) Scalar {
            return v.v[1];
        }

        pub inline fn z(v: *const VecN) Scalar {
            return v.v[2];
        }

        pub inline fn swizzle(
            v: *const VecN,
            xc: VecComponent,
            yc: VecComponent,
            zc: VecComponent,
        ) VecN {
            return .{
                .v = @shuffle(
                    VecN.T,
                    v.v,
                    undefined,
                    [3]T{ @intFromEnum(xc), @intFromEnum(yc), @intFromEnum(zc) },
                ),
            };
        }

        pub inline fn cross(a: *const VecN, b: *const VecN) VecN {
            const s1 = a.swizzle(.y, .z, .x)
                .mul(&b.swizzle(.z, .x, .y));
            const s2 = a.swizzle(.z, .x, .y)
                .mul(&b.swizzle(.y, .z, .x));

            return s1.sub(&s2);
        }

        pub const add = Shared.add;
        pub const sub = Shared.sub;
        pub const mul = Shared.mul;
        pub const div = Shared.div;
        pub const addScalar = Shared.addScalar;
        pub const subScalar = Shared.subScalar;
        pub const mulScalar = Shared.mulScalar;
        pub const divScalar = Shared.divScalar;
        pub const less = Shared.less;
        pub const lessEq = Shared.lessEq;
        pub const greaterEq = Shared.greaterEq;
        pub const greater = Shared.greater;
        pub const len2 = Shared.len2;
        pub const len = Shared.len;
        pub const normalize = Shared.normalize;
        pub const dir = Shared.dir;
        pub const dist2 = Shared.dist2;
        pub const dist = Shared.dist;
        pub const dot = Shared.dot;
        pub const splat = Shared.splat;
        pub const eqlApprox = Shared.eqlApprox;
        pub const eql = Shared.eql;
        pub const format = Shared.format;
    };
}

pub fn VecShared(comptime Scalar: type, comptime VecN: type) type {
    return struct {
        pub inline fn add(a: *const VecN, b: *const VecN) VecN {
            return .{ .v = a.v + b.v };
        }

        pub inline fn sub(a: *const VecN, b: *const VecN) VecN {
            return .{ .v = a.v - b.v };
        }

        pub inline fn mul(a: *const VecN, b: *const VecN) VecN {
            return .{ .v = a.v * b.v };
        }

        pub inline fn div(a: *const VecN, b: *const VecN) VecN {
            return .{ .v = a.v / b.v };
        }

        pub inline fn addScalar(a: *const VecN, s: Scalar) VecN {
            return .{ .v = a.v + VecN.splat(s).v };
        }

        pub inline fn subScalar(a: *const VecN, s: Scalar) VecN {
            return .{ .v = a.v - VecN.splat(s).v };
        }

        pub inline fn mulScalar(a: *const VecN, s: Scalar) VecN {
            return .{ .v = a.v * VecN.splat(s).v };
        }

        pub inline fn divScalar(a: *const VecN, s: Scalar) VecN {
            return .{ .v = a.v / VecN.splat(s).v };
        }

        pub inline fn less(a: *const VecN, b: *const VecN) bool {
            return a.v < b.v;
        }

        pub inline fn lessEq(a: *const VecN, b: *const VecN) bool {
            return a.v <= b.v;
        }

        pub inline fn greaterEq(a: *const VecN, b: *const VecN) bool {
            return a.v >= b.v;
        }

        pub inline fn greater(a: *const VecN, b: *const VecN) bool {
            return a.v > b.v;
        }

        pub inline fn len2(a: *const VecN) Scalar {
            return switch (VecN.n) {
                inline 2 => a.x() * a.x() + a.y() * a.y(),
                inline 3 => a.x() * a.x() + a.y() * a.y() + a.z() * a.z(),
                else => @compileError("Expected Vec2 or Vec3, found '" ++ @typeName(VecN) ++ "'"),
            };
        }

        pub inline fn len(a: *const VecN) Scalar {
            return @sqrt(len2(a));
        }

        pub inline fn normalize(v: *const VecN) VecN {
            return v.div(&VecN.splat(v.len()));
        }

        pub inline fn dir(a: *const VecN, b: *const VecN) VecN {
            return b.sub(a).normalize();
        }

        pub inline fn dist2(a: *const VecN, b: *const VecN) Scalar {
            return b.sub(a).len2();
        }

        pub inline fn dist(a: *const VecN, b: *const VecN) Scalar {
            return @sqrt(a.dist2(b));
        }

        pub inline fn dot(a: *const VecN, b: *const VecN) Scalar {
            return @reduce(.Add, a.v * b.v);
        }

        pub inline fn splat(scalar: Scalar) VecN {
            return .{ .v = @splat(scalar) };
        }

        pub inline fn eqlApprox(a: *const VecN, b: *const VecN, eps: Scalar) bool {
            var i: usize = 0;
            while (i < VecN.n) : (i += 1) {
                if (!std.math.approxEqAbs(Scalar, a.v[i], b.v[i], eps)) {
                    return false;
                }
            }
            return true;
        }

        pub inline fn eql(a: *const VecN, b: *const VecN) bool {
            return a.eqlApprox(b, std.math.floatEps(Scalar));
        }

        pub inline fn format(
            self: VecN,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) @TypeOf(writer).Error!void {
            try std.fmt.formatType(self.v, fmt, options, writer, 1);
        }
    };
}
