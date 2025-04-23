const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
});

const std = @import("std");
const Vec2 = @import("physics/vec.zig").Vec2(f32);
const graphics = @import("graphics.zig");
const Particle = @import("physics/Particle.zig");
const physicsConstants = @import("physics/constants.zig");

const Self = @This();

running: bool = true,
alloc: std.mem.Allocator,
particles: std.ArrayList(Particle),

timePreviousFrame: u64 = 0,

pub fn init(alloc: std.mem.Allocator) !Self {
    try graphics.openWindow();

    var particles = std.ArrayList(Particle).init(alloc);

    try particles.append(Particle.init(50, 50, 1));
    try particles.append(Particle.init(50, 100, 5));
    try particles.append(Particle.init(50, 150, 10));

    return .{
        .alloc = alloc,
        .particles = particles,
    };
}

pub fn deinit(self: *Self) void {
    self.particles.deinit();
    graphics.closeWindow();
}

pub fn input(self: *Self) void {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event)) {
        switch (event.type) {
            c.SDL_EVENT_QUIT => self.running = false,
            c.SDL_EVENT_KEY_DOWN => {
                if (event.key.key == c.SDLK_ESCAPE) {
                    self.running = false;
                }
            },
            else => {},
        }
    }
}

pub fn update(self: *Self) void {
    if (self.timePreviousFrame + physicsConstants.MS_PER_FRAME > c.SDL_GetTicks()) {
        const timeElapsed = physicsConstants.MS_PER_FRAME - (c.SDL_GetTicks() - self.timePreviousFrame);
        c.SDL_Delay(@truncate(timeElapsed));
    }
    const deltaTime: f32 = deltaTime: {
        const elapsedTicks: f32 = @floatFromInt(c.SDL_GetTicks() - self.timePreviousFrame);
        const deltaTime = elapsedTicks / 1000.0;
        if (deltaTime > 4 * physicsConstants.MS_PER_FRAME) {
            break :deltaTime physicsConstants.MS_PER_FRAME;
        }
        break :deltaTime deltaTime;
    };

    self.timePreviousFrame = c.SDL_GetTicks();

    for (self.particles.items) |*particle| {
        // Wind
        particle.addForce(&Vec2.init(0.2 * physicsConstants.PIXELS_PER_METER, 0));

        // Weight
        particle.addForce(&Vec2.init(0, 9.8 * physicsConstants.PIXELS_PER_METER).mulScalar(particle.mass));

        var bounce = Vec2.init(1, 1);
        const currentY: i32 = @intFromFloat(particle.position.y());
        const currentX: i32 = @intFromFloat(particle.position.x());

        if (currentY >= graphics.height() - particle.radius) {
            particle.position.setY(@floatFromInt(graphics.height() - particle.radius));
            bounce.setY(-0.8);
        }
        if (currentY <= particle.radius) {
            particle.position.setY(@floatFromInt(particle.radius));
            bounce.setY(-0.8);
        }

        if (currentX >= graphics.width() - particle.radius) {
            particle.position.setX(@floatFromInt(graphics.width() - particle.radius));
            bounce.setX(-0.8);
        }
        if (currentX <= particle.radius) {
            particle.position.setX(@floatFromInt(particle.radius));
            bounce.setX(-0.8);
        }
        particle.velocity = particle.velocity.mul(&bounce);

        particle.integrate(deltaTime);
    }
}

pub fn render(self: *Self) void {
    graphics.clearScreen(0xFF636205);

    for (self.particles.items) |particle| {
        graphics.drawFillCircle(
            particle.position.x(),
            particle.position.y(),
            @floatFromInt(particle.radius),
            0xFFFFFFFF,
        );
    }

    graphics.renderFrame();
}

pub fn isRunning(self: *const Self) bool {
    return self.running;
}
