const std = @import("std");
const vec = @import("vec.zig");
const Vec2 = vec.Vec2(f32);
const shapes = @import("shapes.zig");
const Shape = shapes.Shape;
const Body = @import("Body.zig");

pub const Contact = struct {
    a: *Body,
    b: *Body,

    start: Vec2,
    end: Vec2,

    normal: Vec2,
    depth: f32,

    pub fn resolvePenetration(self: *Contact) void {
        if (self.a.isStatic() and self.b.isStatic()) {
            return;
        }

        const totalInvMass = self.a.invMass + self.b.invMass;
        const da = self.depth / totalInvMass * self.a.invMass;
        const db = self.depth / totalInvMass * self.b.invMass;

        self.a.position = self.a.position.sub(&self.normal.mulScalar(da));
        self.b.position = self.b.position.add(&self.normal.mulScalar(db));
    }

    pub fn resolveCollision(self: *Contact) void {
        const e = @min(self.a.restitution, self.b.restitution);
        const vRel = self.a.velocity.sub(&self.b.velocity);

        const impulse = -(1 + e) * vRel.dot(&self.normal) / (self.a.invMass + self.b.invMass);
        const Jn = self.normal.mulScalar(impulse);

        self.a.applyImpulse(&Jn);
        self.b.applyImpulse(&Jn.negate());
    }
};

pub fn isColliding(a: *Body, b: *Body, contact: *Contact) bool {
    return switch (a.shape) {
        .circle => |aShape| switch (b.shape) {
            .circle => |bShape| isCollidingCircleCircle(a, b, aShape.radius, bShape.radius, contact),
            else => false,
        },
        .box => |aShape| switch (b.shape) {
            .box => |bShape| isCollidingPolyPoly(a, b, aShape.worldVertices.items, bShape.worldVertices.items, contact),
            .polygon => |bShape| isCollidingPolyPoly(a, b, aShape.worldVertices.items, bShape.worldVertices.items, contact),
            else => false,
        },
        .polygon => |aShape| switch (b.shape) {
            .box => |bShape| isCollidingPolyPoly(a, b, aShape.worldVertices.items, bShape.worldVertices.items, contact),
            .polygon => |bShape| isCollidingPolyPoly(a, b, aShape.worldVertices.items, bShape.worldVertices.items, contact),
            else => false,
        },
    };
}

inline fn isCollidingCircleCircle(a: *Body, b: *Body, ra: f32, rb: f32, contact: *Contact) bool {
    const radiusSum = ra + rb;
    const ab = b.position.sub(&a.position);
    const isCollision = ab.len2() <= radiusSum * radiusSum;

    if (isCollision) {
        contact.a = a;
        contact.b = b;

        contact.normal = ab.normalize();

        contact.start = b.position.sub(&contact.normal.mulScalar(rb));
        contact.end = a.position.add(&contact.normal.mulScalar(ra));

        contact.depth = contact.end.sub(&contact.start).len();
    }

    return isCollision;
}

inline fn isCollidingPolyPoly(a: *Body, b: *Body, verticesA: []Vec2, verticesB: []Vec2, contact: *Contact) bool {
    var aAxis = Vec2.init(0, 0);
    var aPoint = Vec2.init(0, 0);
    const abSeparation = findMinSeparation(verticesA, verticesB, &aAxis, &aPoint);

    if (abSeparation > 0) {
        return false;
    }

    var bAxis = Vec2.init(0, 0);
    var bPoint = Vec2.init(0, 0);
    const baSeparation = findMinSeparation(verticesB, verticesA, &bAxis, &bPoint);
    if (baSeparation > 0) {
        return false;
    }

    contact.a = a;
    contact.b = b;

    if (abSeparation > baSeparation) {
        contact.depth = -abSeparation;
        contact.normal = aAxis.normal();
        contact.start = aPoint;
        contact.end = aPoint.add(&contact.normal.mulScalar(contact.depth));
    } else {
        contact.depth = -baSeparation;
        contact.normal = bAxis.normal().negate();
        contact.start = bPoint.sub(&contact.normal.mulScalar(contact.depth));
        contact.end = bPoint;
    }
    return true;
}

fn findMinSeparation(verticesA: []Vec2, verticesB: []Vec2, axisOut: *Vec2, pointOut: *Vec2) f32 {
    var separation = std.math.floatMin(f32);

    for (verticesA, 0..) |va, i| {
        const edge = shapes.edgeAt(verticesA, i);
        const normal = edge.normal();
        var minSep = std.math.floatMax(f32);
        var minVertex: Vec2 = undefined;

        for (verticesB) |vb| {
            const projection = normal.dot(&vb.sub(&va));
            if (projection < minSep) {
                minSep = projection;
                minVertex = vb;
            }
        }

        if (minSep > separation) {
            separation = minSep;
            axisOut.* = edge;
            pointOut.* = minVertex;
        }
    }

    return separation;
}
