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
const force = @import("physics/force.zig");

const Self = @This();

const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

running: bool = true,
alloc: std.mem.Allocator,
particles: std.ArrayList(Particle),
pushForce: Vec2 = Vec2.init(0, 0),
liquid: Rect,
anchor: Vec2,

timePreviousFrame: u64 = 0,

pub fn init(alloc: std.mem.Allocator) !Self {
    try graphics.openWindow();

    var particles = std.ArrayList(Particle).init(alloc);

    // try particles.append(Particle.init(50, 50, 1, 4));
    // try particles.append(Particle.init(100, 100, 5, 10));
    try particles.append(Particle.init(50, 150, 10, 4));

    return .{
        .alloc = alloc,
        .particles = particles,
        .anchor = Vec2.init(200, 200),
        .liquid = Rect{
            .x = 0,
            .y = @floatFromInt(graphics.height() / 2),
            .w = @floatFromInt(graphics.width()),
            .h = @floatFromInt(graphics.height() / 2),
        },
    };
}

pub fn deinit(self: *Self) void {
    self.particles.deinit();
    graphics.closeWindow();
}

pub fn input(self: *Self) !void {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event)) {
        switch (event.type) {
            c.SDL_EVENT_QUIT => self.running = false,
            c.SDL_EVENT_KEY_DOWN => {
                switch (event.key.key) {
                    c.SDLK_ESCAPE => self.running = false,
                    c.SDLK_UP => self.pushForce.setY(-50 * physicsConstants.PIXELS_PER_METER),
                    c.SDLK_DOWN => self.pushForce.setY(50 * physicsConstants.PIXELS_PER_METER),
                    c.SDLK_LEFT => self.pushForce.setX(-50 * physicsConstants.PIXELS_PER_METER),
                    c.SDLK_RIGHT => self.pushForce.setX(50 * physicsConstants.PIXELS_PER_METER),
                    else => {},
                }
            },
            c.SDL_EVENT_KEY_UP => {
                switch (event.key.key) {
                    c.SDLK_ESCAPE => self.running = false,
                    c.SDLK_UP => self.pushForce.setY(0),
                    c.SDLK_DOWN => self.pushForce.setY(0),
                    c.SDLK_LEFT => self.pushForce.setX(0),
                    c.SDLK_RIGHT => self.pushForce.setX(0),
                    else => {},
                }
            },
            c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                if (event.button.button == c.SDL_BUTTON_LEFT) {
                    try self.particles.append(Particle.init(
                        event.button.x,
                        event.button.y,
                        1,
                        4,
                    ));
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
        // // Wind
        // particle.addForce(&Vec2.init(0.2 * physicsConstants.PIXELS_PER_METER, 0));
        //
        // // Weight
        // particle.addForce(&force.weight(particle, 9.8));
        //
        // Push
        particle.addForce(&self.pushForce);
        //
        // // Friction
        // particle.addForce(&force.friction(particle, 10 * physicsConstants.PIXELS_PER_METER));

        // Liquid drag
        // if (particle.position.y() >= self.liquid.y) {
        //     particle.addForce(&force.drag(particle, 0.01));
        // }

        // Gravity
        // for (self.particles.items) |*otherParticle| {
        //     if (particle == otherParticle) continue;
        //     const attraction = force.gravitational(particle, otherParticle, 10 * physicsConstants.PIXELS_PER_METER, 5, 100);
        //     particle.addForce(&attraction);
        // }

        particle.addForce(&force.spring(particle, &self.anchor, 100, 10));
        particle.integrate(deltaTime);

        var bounce = Vec2.init(1, 1);
        const currentX: i32 = @intFromFloat(particle.position.x());
        const currentY: i32 = @intFromFloat(particle.position.y());

        if (currentY > graphics.height() - particle.radius) {
            particle.position.setY(@floatFromInt(graphics.height() - particle.radius * 2));
            bounce.setY(-0.8);
        }
        if (currentY < particle.radius) {
            particle.position.setY(@floatFromInt(particle.radius));
            bounce.setY(-0.8);
        }

        if (currentX > graphics.width() - particle.radius) {
            particle.position.setX(@floatFromInt(graphics.width() - particle.radius));
            bounce.setX(-0.8);
        }
        if (currentX < particle.radius) {
            particle.position.setX(@floatFromInt(particle.radius));
            bounce.setX(-0.8);
        }
        particle.velocity = particle.velocity.mul(&bounce);
    }
}

pub fn render(self: *const Self) void {
    graphics.clearScreen(0xFF636205);

    graphics.drawFillRect(
        self.liquid.x + self.liquid.w / 2,
        self.liquid.y + self.liquid.h / 2,
        self.liquid.w,
        self.liquid.h,
        0xFF6E3712,
    );

    graphics.drawFillCircle(
        self.anchor.x(),
        self.anchor.y(),
        10,
        0xFF6E3712,
    );

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
