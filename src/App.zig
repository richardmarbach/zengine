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
particle: Particle,

timePreviousFrame: u64,

pub fn init(alloc: std.mem.Allocator) !Self {
    try graphics.openWindow();

    return .{
        .alloc = alloc,
        .particle = Particle.init(50, 100, 1),
        .timePreviousFrame = 0,
    };
}

pub fn deinit(_: *Self) void {
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

    self.particle.velocity = Vec2.init(100, 50).mulScalar(deltaTime);
    self.particle.position = self.particle.position.add(&self.particle.velocity);
}

pub fn render(self: *Self) void {
    graphics.clearScreen(0xFF636205);

    graphics.drawFillCircle(
        self.particle.position.x(),
        self.particle.position.y(),
        4,
        0xFFFFFFFF,
    );

    graphics.renderFrame();
}

pub fn isRunning(self: *const Self) bool {
    return self.running;
}
