const std = @import("std");
const Particle = @import("Particle.zig");
const vec = @import("vec.zig");
const Vec2 = vec.Vec2(f32);

pub fn weight(particle: *const Particle, gravity: f32) Vec2 {
    return Vec2.init(0, particle.mass * gravity);
}

pub fn drag(particle: *const Particle, dragCoefficient: f32) Vec2 {
    const velocity2 = particle.velocity.len2();
    if (velocity2 == 0) {
        return Vec2.init(0, 0);
    }

    return particle.velocity.normalize()
        .negate()
        .mulScalar(dragCoefficient)
        .mulScalar(velocity2);
}

pub fn friction(particle: *const Particle, k: f32) Vec2 {
    const velocity2 = particle.velocity.len2();
    if (velocity2 == 0) {
        return Vec2.init(0, 0);
    }

    return particle.velocity.normalize().mulScalar(-k);
}

pub fn gravitational(a: *const Particle, b: *const Particle, G: f32, minDistance: f32, maxDistance: f32) Vec2 {
    const d = b.position.sub(&a.position);
    const d2 = d.len2();

    const distance = std.math.clamp(d2, minDistance, maxDistance);
    const attractionDirection = d.normalize();
    const attractionMagnitude = G * a.mass * b.mass / distance;

    return attractionDirection.mulScalar(attractionMagnitude);
}

pub fn spring(p: *const Particle, anchor: *const Vec2, restLength: f32, k: f32) Vec2 {
    const d = p.position.sub(anchor);
    const displacement = d.len() - restLength;

    const springDir = d.normalize();
    const sprintMagnitude = -k * displacement;

    return springDir.mulScalar(sprintMagnitude);
}

pub fn springParticle(p: *const Particle, a: *const Particle, restLength: f32, k: f32) Vec2 {
    return spring(p, &a.position, restLength, k);
}
