const Body = @import("Body.zig");
const mat = @import("mat.zig");
const vec = @import("vec.zig");
const Vec2 = vec.Vec2(f32);
const std = @import("std");

const J1 = mat.MatMxN(f32, 1, 6);
const J2 = mat.MatMxN(f32, 2, 6);
const M1x1 = mat.MatMxN(f32, 1, 1);
const M2x2 = mat.MatMxN(f32, 2, 2);
const M6x6 = mat.MatMxN(f32, 6, 6);

a: *Body,
b: *Body,

aPoint: Vec2, // Anchor in A's local space
bPoint: Vec2, // Anchor in B's local space

bias: f32 = 0.0,

constraint: union(enum) {
    joint: struct {
        lambda: f32 = 0.0,
        K: M1x1 = M1x1.zero(),
        jacobian: J1 = J1.zero(),
    },
    penetration: struct {
        friction: f32 = 0,
        normal: Vec2,
        K: M2x2 = M2x2.zero(),
        jacobian: J2 = J2.zero(),
        lambda: vec.Vec(f32, 2) = vec.Vec(f32, 2).zero(),
    },
},

const Self = @This();

pub fn initPenetration(
    a: *Body,
    b: *Body,
    collisionA: *const Vec2,
    collisionB: *const Vec2,
    normal: *const Vec2,
) Self {
    return .{
        .a = a,
        .b = b,
        .aPoint = a.toLocalSpace(collisionA),
        .bPoint = b.toLocalSpace(collisionB),
        .constraint = .{
            .penetration = .{
                .normal = a.toLocalSpace(normal),
            },
        },
    };
}

pub fn initJoint(a: *Body, b: *Body, anchor: *const Vec2) Self {
    return .{
        .a = a,
        .b = b,
        .aPoint = a.toLocalSpace(anchor),
        .bPoint = b.toLocalSpace(anchor),
        .constraint = .{
            .joint = .{},
        },
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

pub fn velocities(self: *const Self) J1.RowVec {
    return J1.RowVec.init(
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
    const pa = self.a.toWorldSpace(&self.aPoint);
    const pb = self.b.toWorldSpace(&self.bPoint);

    const ra = pa.sub(&self.a.position);
    const rb = pb.sub(&self.b.position);

    switch (self.constraint) {
        .joint => |*joint| {
            const j1 = pa.sub(&pb).mulScalar(2);
            const j2 = pb.sub(&pa).mulScalar(2);

            const j = J1.init(.{.{
                j1.x(),
                j1.y(),
                ra.cross(&pa.sub(&pb)) * 2,
                j2.x(),
                j2.y(),
                rb.cross(&pb.sub(&pa)) * 2,
            }});
            const jt = j.transpose();
            const iM = self.invM();

            joint.jacobian = j;
            joint.K = j.mulM(&iM).mulM(&jt);

            // Warm start
            const impulses = j.mulScalar(joint.lambda).row(0);

            self.a.applyImpulse(&Vec2.init(impulses.v[0], impulses.v[1]));
            self.a.applyImpulseAngular(impulses.v[2]);
            self.b.applyImpulse(&Vec2.init(impulses.v[3], impulses.v[4]));
            self.b.applyImpulseAngular(impulses.v[5]);

            // Baumgarte stabilization
            const beta = 0.1;
            // Positional error
            var C = pb.sub(&pa).dot(&pb.sub(&pa));
            C = @max(0, C - beta);
            self.bias = (beta / deltaTime) * C;
        },
        .penetration => |*penetration| {
            const n = self.a.toWorldSpace(&penetration.normal);
            penetration.friction = @max(self.a.friction, self.b.friction);
            const t = n.normal().mulScalar(penetration.friction);
            const j = J2.init(.{
                .{
                    -n.x(),
                    -n.y(),
                    ra.negate().cross(&n),
                    n.x(),
                    n.y(),
                    rb.cross(&n),
                },
                .{
                    -t.x(),
                    -t.y(),
                    ra.negate().cross(&t),
                    t.x(),
                    t.y(),
                    rb.cross(&t),
                },
            });
            const jt = j.transpose();
            const iM = self.invM();

            penetration.jacobian = j;
            penetration.K = j.mulM(&iM).mulM(&jt);

            // Warm start
            // const impulses = jt.mulVec(&penetration.lambda);
            //
            // self.a.applyImpulse(&Vec2.init(impulses.v[0], impulses.v[1]));
            // self.a.applyImpulseAngular(impulses.v[2]);
            // self.b.applyImpulse(&Vec2.init(impulses.v[3], impulses.v[4]));
            // self.b.applyImpulseAngular(impulses.v[5]);

            // Baumgarte stabilization
            const beta = 0.1;
            // Positional error
            var C = pb.sub(&pa).dot(&n.negate());
            C = @min(0, C + beta);
            self.bias = (beta / deltaTime) * C;
        },
    }
}

pub fn postSolve(_: *Self) void {}

pub fn solve(self: *Self) void {
    const v = self.velocities();

    switch (self.constraint) {
        .joint => |*joint| {
            const j = joint.jacobian;

            const rhs = j.mulVec(&v).mulScalar(-1).subScalar(self.bias);
            const lambda = joint.K.solveGaussSeidel(&rhs);
            std.debug.assert(@TypeOf(lambda).n == 1);

            joint.lambda += lambda.v[0];
            const impulses = j.mulScalar(lambda.v[0]).row(0);

            self.a.applyImpulse(&Vec2.init(impulses.v[0], impulses.v[1]));
            self.a.applyImpulseAngular(impulses.v[2]);
            self.b.applyImpulse(&Vec2.init(impulses.v[3], impulses.v[4]));
            self.b.applyImpulseAngular(impulses.v[5]);
        },
        .penetration => |*penetration| {
            const j = penetration.jacobian;
            const jt = j.transpose();

            const rhs = j.mulVec(&v).mulScalar(-1).subScalar(self.bias);
            const lambda = penetration.K.solveGaussSeidel(&rhs);
            std.debug.assert(@TypeOf(lambda).n == 2);

            // const oldLambda = penetration.lambda;
            // penetration.lambda = penetration.lambda.add(&lambda);
            // penetration.lambda = penetration.lambda.max(&vec.Vec(f32, 2).zero());
            // penetration.lambda = penetration.lambda.sub(&oldLambda);

            const impulses = jt.mulVec(&lambda);

            std.debug.print("impulses {f} {f} {f} \n", .{ jt, impulses, lambda });

            self.a.applyImpulse(&Vec2.init(impulses.v[0], impulses.v[1]));
            self.a.applyImpulseAngular(impulses.v[2]);
            self.b.applyImpulse(&Vec2.init(impulses.v[3], impulses.v[4]));
            self.b.applyImpulseAngular(impulses.v[5]);
        },
    }
}

test "correctly resolves penetration constraint" {
    const shapes = @import("shapes.zig");
    var a = Body.init(shapes.Shape{ .circle = shapes.Circle{ .radius = 64 } }, 0, 0, 1);
    var b = Body.init(shapes.Shape{ .circle = shapes.Circle{ .radius = 64 } }, 0, 0, 1);
    a.velocity = Vec2.init(0, 0);
    b.velocity = Vec2.init(0, -1);
    const collisionA = Vec2.init(951.72565, 490.68204);
    const collisionB = Vec2.init(949.41034, 476.88217);
    const normal = Vec2.init(-0.16546346, -0.9862159);
    var penetration = initPenetration(&a, &b, &collisionA, &collisionB, &normal);

    penetration.preSolve(1.0 / 60.0);
    penetration.solve();
}
