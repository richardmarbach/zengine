const vec = @import("vec.zig");
const Vec2 = vec.Vec2(f32);
const Shape = @import("shapes.zig").Shape;
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
        else => false,
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
