const std = @import("std");
const Body = @import("Body.zig");
const Vec2 = @import("vec.zig").Vec2(f32);
const physicsConstants = @import("constants.zig");
const Forces = @import("force.zig");
const collisions = @import("collision.zig");

const World = @This();

gravity: f32,
bodies: std.ArrayList(Body),

forces: std.ArrayList(Vec2),
torques: std.ArrayList(f32),

pub fn init(alloc: std.mem.Allocator, gravity: f32) World {
    return .{
        .gravity = gravity,
        .bodies = std.ArrayList(Body).init(alloc),
        .forces = std.ArrayList(Vec2).init(alloc),
        .torques = std.ArrayList(f32).init(alloc),
    };
}

pub fn deinit(self: *World) void {
    for (self.bodies.items) |*body| {
        body.deinit();
    }

    self.bodies.deinit();
    self.forces.deinit();
    self.torques.deinit();
}

pub fn addBody(self: *World, body: Body) !void {
    try self.bodies.append(body);
}

pub fn addForce(self: *World, force: Vec2) !void {
    try self.forces.append(force);
}

pub fn addTorque(self: *World, torque: f32) !void {
    try self.torques.append(torque);
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

        body.update(deltaTime);
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

