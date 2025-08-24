const Body = @import("Body.zig");
const mat = @import("mat.zig");
const Vec2 = @import("vec.zig").Vec2(f32);
const std = @import("std");

const J = mat.MatMxN(f32, 1, 6);
const M1x1 = mat.MatMxN(f32, 1, 1);
const M6x6 = mat.MatMxN(f32, 6, 6);

a: *Body,
b: *Body,

aPoint: Vec2, // Anchor in A's local space
bPoint: Vec2, // Anchor in B's local space

lambda: f32 = 0.0,
jacobian: J = J.zero(),
bias: f32 = 0.0,

constraint: union(enum) {
    joint: struct {
        K: M1x1 = M1x1.zero(),
    },
},

const Self = @This();

pub fn initJoint(a: *Body, b: *Body, anchor: *const Vec2) Self {
    return .{
        .a = a,
        .b = b,
        .aPoint = a.toLocalSpace(anchor),
        .bPoint = b.toLocalSpace(anchor),
        .constraint = .{ .joint = .{} },
    };
}

pub fn invM(self: *const Self) M6x6 {
    var m = M6x6.zero();
    m.v[0].v[0] = self.a.invMass;
    m.v[1].v[1] = self.a.invMass;
    m.v[2].v[2] = self.a.invI;
    m.v[3].v[3] = self.b.invMass;
    m.v[4].v[4] = self.b.invMass;
    m.v[5].v[5] = self.b.invI;
    return m;
}

pub fn velocities(self: *const Self) J.RowVec {
    return J.RowVec.init(
        .{
            self.a.velocity.x(),
            self.a.velocity.y(),
            self.a.angularVelocity,
            self.b.velocity.x(),
            self.b.velocity.y(),
            self.b.angularVelocity,
        },
    );
}

pub fn preSolve(self: *Self, deltaTime: f32) void {
    switch (self.constraint) {
        .joint => |*joint| {
            const pa = self.a.toWorldSpace(&self.aPoint);
            const pb = self.b.toWorldSpace(&self.bPoint);

            const ra = pa.sub(&self.a.position);
            const rb = pb.sub(&self.b.position);

            const j1 = pa.sub(&pb).mulScalar(2);
            const j2 = pb.sub(&pa).mulScalar(2);

            const j = J.init(.{.{
                j1.x(),
                j1.y(),
                ra.cross(&pa.sub(&pb)) * 2,
                j2.x(),
                j2.y(),
                rb.cross(&pb.sub(&pa)) * 2,
            }});
            const jt = j.transpose();
            const iM = self.invM();

            self.jacobian = j;
            joint.K = j.mulM(&iM).mulM(&jt);

            // Warm start
            const impulses = j.mulScalar(self.lambda).row(0);

            self.a.applyImpulse(&Vec2.init(impulses.v[0], impulses.v[1]));
            self.a.applyImpulseAngular(impulses.v[2]);
            self.b.applyImpulse(&Vec2.init(impulses.v[3], impulses.v[4]));
            self.b.applyImpulseAngular(impulses.v[5]);

            // Baumgarte stabilization
            const beta = 0.1;
            // Positional error
            var C = pb.sub(&pa).dot(&pb.sub(&pa));
            C = std.math.clamp(C, 0, @max(0, C - beta));
            self.bias = (beta / deltaTime) * C;
        },
    }
}

pub fn postSolve(_: *Self) void {}

pub fn solve(self: *Self) void {
    const v = self.velocities();

    switch (self.constraint) {
        .joint => |joint| {
            const j = self.jacobian;

            const rhs = j.mulVec(&v).mulScalar(-1).subScalar(self.bias);
            const lambda = joint.K.solveGaussSeidel(&rhs);
            std.debug.assert(@TypeOf(lambda).n == 1);

            self.lambda += lambda.v[0];
            const impulses = j.mulScalar(lambda.v[0]).row(0);

            self.a.applyImpulse(&Vec2.init(impulses.v[0], impulses.v[1]));
            self.a.applyImpulseAngular(impulses.v[2]);
            self.b.applyImpulse(&Vec2.init(impulses.v[3], impulses.v[4]));
            self.b.applyImpulseAngular(impulses.v[5]);
        },
    }
}
