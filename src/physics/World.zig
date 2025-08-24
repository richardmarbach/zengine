const std = @import("std");
const Body = @import("Body.zig");
const Vec2 = @import("vec.zig").Vec2(f32);
const physicsConstants = @import("constants.zig");
const Forces = @import("force.zig");
const collisions = @import("collision.zig");
const Constraint = @import("constraint.zig");

const World = @This();

gravity: f32,
bodies: std.ArrayList(Body),
constraints: std.ArrayList(Constraint),

forces: std.ArrayList(Vec2),
torques: std.ArrayList(f32),

pub fn init(gravity: f32) World {
    return .{
        .gravity = gravity,
        .bodies = std.ArrayList(Body){},
        .forces = std.ArrayList(Vec2){},
        .torques = std.ArrayList(f32){},
        .constraints = std.ArrayList(Constraint){},
    };
}

pub fn deinit(self: *World, alloc: std.mem.Allocator) void {
    for (self.bodies.items) |*body| {
        body.deinit(alloc);
    }

    self.constraints.deinit(alloc);
    self.bodies.deinit(alloc);
    self.forces.deinit(alloc);
    self.torques.deinit(alloc);
}

pub fn addBody(self: *World, alloc: std.mem.Allocator, body: Body) !void {
    try self.bodies.append(alloc, body);
}

pub fn addForce(self: *World, alloc: std.mem.Allocator, force: Vec2) !void {
    try self.forces.append(alloc, force);
}

pub fn addTorque(self: *World, alloc: std.mem.Allocator, torque: f32) !void {
    try self.torques.append(alloc, torque);
}

pub fn addConstraint(self: *World, alloc: std.mem.Allocator, constraint: Constraint) !void {
    try self.constraints.append(alloc, constraint);
}

pub fn update(self: *World, deltaTime: f32) void {
    for (self.bodies.items) |*body| {
        const weight = Forces.weight(body, self.gravity * physicsConstants.PIXELS_PER_METER);
        body.addForce(&weight);

        for (self.forces.items) |force| {
            body.addForce(&force);
        }

        for (self.torques.items) |torque| {
            body.addTorque(torque);
        }

        body.integrateForces(deltaTime);
    }

    for (self.constraints.items) |*constraint| {
        constraint.preSolve(deltaTime);
    }

    for (0..5) |_| {
        for (self.constraints.items) |*constraint| {
            constraint.solve();
        }
    }

    for (self.bodies.items) |*body| {
        body.integrateVelocities(deltaTime);
    }

    self.checkCollisions();
}

pub fn checkCollisions(self: *World) void {
    for (self.bodies.items, 0..) |*a, i| {
        for (self.bodies.items[i + 1 ..]) |*b| {
            var contact: collisions.Contact = undefined;
            if (collisions.isColliding(a, b, &contact)) {
                contact.resolveCollision();
            }
        }
    }
}
