const std = @import("std");
const physicsConstants = @import("constants.zig");
const Particle = @import("Particle.zig");
const vec = @import("vec.zig");
const Vec2 = vec.Vec2(f32);

pub fn weight(particle: *const Particle, gravity: f32) Vec2 {
    return Vec2.init(0, particle.mass * gravity * physicsConstants.PIXELS_PER_METER);
}

pub fn drag(particle: *const Particle, dragCoefficient: f32) Vec2 {
    const velocity2 = particle.velocity.len2();
    if (velocity2 == 0) {
        return Vec2.init(0, 0);
    }

    return particle.velocity.normalize()
        .mulScalar(-dragCoefficient)
        .mulScalar(velocity2);
}
