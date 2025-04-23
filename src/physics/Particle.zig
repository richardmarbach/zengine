const vec = @import("vec.zig");
const Vec2 = vec.Vec2(f32);

const Self = @This();

position: Vec2,
velocity: Vec2,
acceleration: Vec2,

radius: u32 = 4,
mass: f32,
invMass: f32,
sumForces: Vec2 = Vec2.init(0, 0),

pub fn init(x: f32, y: f32, mass: f32) Self {
    return .{
        .position = Vec2.init(x, y),
        .velocity = Vec2.init(0, 0),
        .acceleration = Vec2.init(0, 0),
        .mass = mass,
        .invMass = if (mass == 0) 0 else 1 / mass,
    };
}

pub inline fn addForce(self: *Self, force: *const Vec2) void {
    self.sumForces = self.sumForces.add(force);
}

pub fn integrate(self: *Self, dt: f32) void {
    self.acceleration = self.sumForces.mulScalar(self.invMass);

    self.velocity = self.velocity.add(&self.acceleration.mulScalar(dt));
    self.position = self.position.add(&self.velocity.mulScalar(dt));

    self.clearForces();
}

pub inline fn clearForces(self: *Self) void {
    self.sumForces = Vec2.init(0, 0);
}
