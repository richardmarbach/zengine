const std = @import("std");

const graphics = @import("graphics.zig");
const Body = @import("physics/Body.zig");
const physicsConstants = @import("physics/constants.zig");
const force = @import("physics/force.zig");
const shapes = @import("physics/shapes.zig");

const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
});

const Vec2 = @import("physics/vec.zig").Vec2(f32);
const Box = struct {
    tl: *Body,
    tr: *Body,
    bl: *Body,
    br: *Body,
    size: f32,
    diagonal: f32,
    k: f32,
};

const Self = @This();

running: bool = true,
alloc: std.mem.Allocator,
bodies: std.ArrayList(Body),
pushForce: Vec2 = Vec2.init(0, 0),

timePreviousFrame: u64 = 0,

pub fn init(alloc: std.mem.Allocator) !Self {
    try graphics.openWindow();

    var bodies = std.ArrayList(Body).init(alloc);

    // Top left
    try bodies.append(Body.init(
        shapes.Shape{ .circle = .{ .radius = 50 } },
        @floatFromInt(graphics.width() / 2),
        @floatFromInt(graphics.height() / 2),
        1.0,
    ));
    return .{
        .alloc = alloc,
        .bodies = bodies,
    };
}

pub fn deinit(self: *Self) void {
    self.bodies.deinit();
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
                    try self.bodies.append(Body.init(
                        shapes.Shape{ .circle = .{ .radius = 4 } },
                        event.button.x,
                        event.button.y,
                        1,
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

    for (self.bodies.items) |*body| {
        // Push
        body.addForce(&self.pushForce);

        body.addForce(&force.drag(body, 0.003));
        body.addForce(&force.weight(body, 9.8 * physicsConstants.PIXELS_PER_METER));

        body.integrate(deltaTime);
    }

    for (self.bodies.items) |*body| {
        var bounce = Vec2.init(1, 1);
        const currentX: i32 = @intFromFloat(body.position.x());
        const currentY: i32 = @intFromFloat(body.position.y());
        switch (body.shape) {
            .circle => |circle| {
                if (currentY + circle.radiusW(i32) >= graphics.height()) {
                    body.position.setY(@floatFromInt(graphics.height() - circle.radiusW(u32)));
                    bounce.setY(-0.8);
                } else if (currentY < circle.radiusW(u32)) {
                    body.position.setY(circle.radius);
                    bounce.setY(-0.8);
                }

                if (currentX > graphics.width() - circle.radiusW(u32)) {
                    body.position.setX(@floatFromInt(graphics.width() - circle.radiusW(u32)));
                    bounce.setX(-0.8);
                } else if (currentX < circle.radiusW(i32)) {
                    body.position.setX(circle.radius);
                    bounce.setX(-0.8);
                }
            },
            else => {},
        }
        body.velocity = body.velocity.mul(&bounce);
    }
}

pub fn render(self: *const Self) void {
    graphics.clearScreen(0xFF3D3D3C);

    for (self.bodies.items) |body| {
        switch (body.shape) {
            .circle => |circle| graphics.drawCircle(body.position.x(), body.position.y(), circle.radius, 0, 0xFFFFFFFF),
            else => @panic("Shape not supported yet"),
        }
    }

    graphics.renderFrame();
}

pub fn isRunning(self: *const Self) bool {
    return self.running;
}
