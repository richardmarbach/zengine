const vec = @import("vec.zig");
const Vec2 = vec.Vec2(f32);

const Self = @This();

position: Vec2,
velocity: Vec2,
acceleration: Vec2,

radius: u32 = 4,
mass: f32,

pub fn init(x: f32, y: f32, mass: f32) Self {
    return .{
        .position = Vec2.init(x, y),
        .velocity = Vec2.init(0, 0),
        .acceleration = Vec2.init(0, 0),
        .mass = mass,
    };
}
