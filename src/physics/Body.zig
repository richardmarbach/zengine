const vec = @import("vec.zig");
const Vec2 = vec.Vec2(f32);
const Shape = @import("shapes.zig").Shape;

const Self = @This();

position: Vec2,
velocity: Vec2,
acceleration: Vec2,

mass: f32,
invMass: f32,
sumForces: Vec2 = Vec2.init(0, 0),

rotation: f32,
angularVelocity: f32,
angularAcceleration: f32,
I: f32,
invI: f32,
sumTorque: f32 = 0,

shape: Shape,

pub fn init(shape: Shape, x: f32, y: f32, mass: f32) Self {
    const I = shape.momentOfInertia() * mass;

    return .{
        .position = Vec2.init(x, y),
        .velocity = Vec2.init(0, 0),
        .acceleration = Vec2.init(0, 0),
        .mass = mass,
        .invMass = if (mass == 0) 0 else 1 / mass,
        .shape = shape,
        .rotation = 0,
        .angularVelocity = 0,
        .angularAcceleration = 0,
        .I = I,
        .invI = if (I == 0) 0 else 1 / I,
    };
}

pub fn deinit(self: *Self) void {
    self.shape.deinit();
}

pub inline fn addTorque(self: *Self, torque: f32) void {
    self.sumTorque += torque;
}

pub inline fn addForce(self: *Self, force: *const Vec2) void {
    self.sumForces = self.sumForces.add(force);
}

pub fn update(self: *Self, dt: f32) void {
    self.integrate(dt);
    self.integrateAngular(dt);
    self.shape.updateVertices(&self.position, self.rotation);
}

pub fn integrate(self: *Self, dt: f32) void {
    self.acceleration = self.sumForces.mulScalar(self.invMass);

    self.velocity = self.velocity.add(&self.acceleration.mulScalar(dt));
    self.position = self.position.add(&self.velocity.mulScalar(dt));

    self.clearForces();
}

pub fn integrateAngular(self: *Self, dt: f32) void {
    self.angularAcceleration = self.sumTorque * self.invI;
    self.angularVelocity += self.angularAcceleration * dt;
    self.rotation += self.angularVelocity * dt;

    self.clearTorque();
}

pub inline fn clearForces(self: *Self) void {
    self.sumForces = Vec2.init(0, 0);
}

pub inline fn clearTorque(self: *Self) void {
    self.sumTorque = 0;
}
