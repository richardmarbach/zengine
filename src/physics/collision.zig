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

        self.a.shape.updateVertices(&self.a.position, self.a.rotation);
        self.b.shape.updateVertices(&self.b.position, self.b.rotation);
    }

    pub fn resolveCollision(self: *Contact) void {
        self.resolvePenetration();

        const e = @min(self.a.restitution, self.b.restitution);
        const ra = self.end.sub(&self.a.position);
        const rb = self.start.sub(&self.b.position);

        const va = self.a.velocity.add(&Vec2.init(-self.a.angularVelocity * ra.y(), self.a.angularVelocity * ra.x()));
        const vb = self.b.velocity.add(&Vec2.init(-self.b.angularVelocity * rb.y(), self.b.angularVelocity * rb.x()));
        const vRel = va.sub(&vb);

        // Collision impulse along the normal
        const raCrossNormal = ra.cross(&self.normal);
        const tbCrossNormal = rb.cross(&self.normal);
        const impulse = -(1 + e) * vRel.dot(&self.normal) / (self.a.invMass + self.b.invMass + raCrossNormal * raCrossNormal * self.a.invI + tbCrossNormal * tbCrossNormal * self.b.invI);
        const Jn = self.normal.mulScalar(impulse);

        // Collision impulse along the tangent
        const tangent = self.normal.normal();
        const raCrossTangent = ra.cross(&tangent);
        const rbCrossTangent = rb.cross(&tangent);
        const angularImpulse = -(1 + e) * vRel.dot(&tangent) / (self.a.invMass + self.b.invMass + raCrossTangent * raCrossTangent * self.a.invI + rbCrossTangent * rbCrossTangent * self.b.invI);
        const Jt = tangent.mulScalar(angularImpulse);

        // Apply the total impulse
        const J = Jn.add(&Jt);
        self.a.applyImpulseAngularAtPoint(&J, &ra);
        self.b.applyImpulseAngularAtPoint(&J.negate(), &rb);
    }
};

pub fn isColliding(a: *Body, b: *Body, contact: *Contact) bool {
    return switch (a.shape) {
        .circle => |aShape| switch (b.shape) {
            .circle => |bShape| isCollidingCircleCircle(a, b, aShape.radius, bShape.radius, contact),
            .box => |bShape| isCollidingCirclePoly(a, b, aShape.radius, bShape.worldVertices.items, contact),
            .polygon => |bShape| isCollidingCirclePoly(a, b, aShape.radius, bShape.worldVertices.items, contact),
        },
        .box => |aShape| switch (b.shape) {
            .box => |bShape| isCollidingPolyPoly(a, b, aShape.worldVertices.items, bShape.worldVertices.items, contact),
            .polygon => |bShape| isCollidingPolyPoly(a, b, aShape.worldVertices.items, bShape.worldVertices.items, contact),
            .circle => |bShape| isCollidingCirclePoly(b, a, bShape.radius, aShape.worldVertices.items, contact),
        },
        .polygon => |aShape| switch (b.shape) {
            .box => |bShape| isCollidingPolyPoly(a, b, aShape.worldVertices.items, bShape.worldVertices.items, contact),
            .polygon => |bShape| isCollidingPolyPoly(a, b, aShape.worldVertices.items, bShape.worldVertices.items, contact),
            .circle => |bShape| isCollidingCirclePoly(b, a, bShape.radius, aShape.worldVertices.items, contact),
        },
    };
}

inline fn isCollidingCirclePoly(circle: *Body, poly: *Body, radius: f32, vertices: []Vec2, contact: *Contact) bool {
    var distanceCircleEdge: f32 = -std.math.floatMax(f32);
    var closestVertex = Vec2.init(0, 0);
    var closestNextVertex = Vec2.init(0, 0);

    for (vertices, 0..) |vertex, i| {
        const edge = shapes.edgeAt(vertices, i);
        const normal = edge.normal();

        const circleCenter = circle.position.sub(&vertex);

        const projection: f32 = circleCenter.dot(&normal);

        if (projection > 0 and projection > distanceCircleEdge) {
            distanceCircleEdge = projection;
            closestVertex = vertex;
            closestNextVertex = vertex.add(&edge);
        } else {
            // We're inside the polygon
            if (projection > distanceCircleEdge) {
                distanceCircleEdge = projection;
                closestVertex = vertex;
                closestNextVertex = vertex.add(&edge);
            }
        }
    }

    const inside = distanceCircleEdge < 0;

    if (inside) {
        contact.a = poly;
        contact.b = circle;
        contact.depth = radius - distanceCircleEdge;
        contact.normal = closestNextVertex.sub(&closestVertex).normal();
        contact.start = circle.position.sub(&contact.normal.mulScalar(radius));
        contact.end = contact.start.add(&contact.normal.mulScalar(contact.depth));
        return true;
    }

    const radius2 = radius * radius;

    //  The collision is either in area A, B or C:
    //        |     |
    //    A   |  C  | B
    //  ------.-----.------
    //        |     |
    //        |     |
    //        .-----.
    //
    blk: { // A
        const closestToCircle = circle.position.sub(&closestVertex);
        const closestEdge = closestNextVertex.sub(&closestVertex);
        if (closestToCircle.dot(&closestEdge) >= 0) break :blk;

        if (closestToCircle.len2() > radius2) {
            return false;
        }

        contact.a = poly;
        contact.b = circle;
        contact.depth = radius - closestToCircle.len();
        contact.normal = closestToCircle.normalize();
        contact.start = circle.position.add(&contact.normal.mulScalar(-radius));
        contact.end = contact.start.add(&contact.normal.mulScalar(contact.depth));
        return true;
    }

    blk: { // B
        const closestToCircle = circle.position.sub(&closestNextVertex);
        const closestEdge = closestVertex.sub(&closestNextVertex);
        if (closestToCircle.dot(&closestEdge) >= 0) break :blk;

        if (closestToCircle.len2() > radius2) {
            return false;
        }

        contact.a = poly;
        contact.b = circle;
        contact.depth = radius - closestToCircle.len();
        contact.normal = closestToCircle.normalize();
        contact.start = circle.position.add(&contact.normal.mulScalar(-radius));
        contact.end = contact.start.add(&contact.normal.mulScalar(contact.depth));
        return true;
    }

    // C
    if (distanceCircleEdge > radius) return false;

    contact.a = poly;
    contact.b = circle;
    contact.depth = radius - distanceCircleEdge;
    contact.normal = closestNextVertex.sub(&closestVertex).normal();
    contact.start = circle.position.sub(&contact.normal.mulScalar(radius));
    contact.end = contact.start.add(&contact.normal.mulScalar(contact.depth));
    return true;
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
    var separation = -std.math.floatMax(f32);

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
