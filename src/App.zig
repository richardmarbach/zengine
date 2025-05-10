const std = @import("std");

const graphics = @import("graphics.zig");
const Body = @import("physics/Body.zig");
const physicsConstants = @import("physics/constants.zig");
const force = @import("physics/force.zig");
const shapes = @import("physics/shapes.zig");
const collisions = @import("physics/collision.zig");

const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
});

const Vec2 = @import("physics/vec.zig").Vec2(f32);

const Self = @This();

running: bool = true,
alloc: std.mem.Allocator,
bodies: std.ArrayList(Body),
pushForce: Vec2 = Vec2.init(0, 0),

timePreviousFrame: u64 = 0,

pub fn init(alloc: std.mem.Allocator) !Self {
    try graphics.openWindow();

    var bodies = std.ArrayList(Body).init(alloc);

    try bodies.append(Body.init(
        shapes.Shape{ .box = try shapes.Box.init(alloc, graphics.width() - 20, 10) },
        @floatFromInt(graphics.width() / 2),
        @floatFromInt(graphics.height() - 10),
        0.0,
    ));
    try bodies.append(Body.init(
        shapes.Shape{ .box = try shapes.Box.init(alloc, 10, graphics.height() - 30) },
        5,
        @floatFromInt(graphics.height() / 2),
        0.0,
    ));
    try bodies.append(Body.init(
        shapes.Shape{ .box = try shapes.Box.init(alloc, 10, graphics.height() - 30) },
        @floatFromInt(graphics.width() - 5),
        @floatFromInt(graphics.height() / 2),
        0.0,
    ));

    var bigBox = Body.init(
        shapes.Shape{ .box = try shapes.Box.init(alloc, 100, 100) },
        @floatFromInt(graphics.width() / 2),
        @floatFromInt(graphics.height() / 2),
        0.0,
    );
    bigBox.rotation = 0.3;
    try bodies.append(bigBox);

    return .{
        .alloc = alloc,
        .bodies = bodies,
    };
}

pub fn deinit(self: *Self) void {
    for (self.bodies.items) |*body| {
        body.deinit();
    }
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
                    var box = Body.init(
                        shapes.Shape{ .box = try shapes.Box.init(self.alloc, 40, 40) },
                        event.button.x,
                        event.button.y,
                        1.0,
                    );
                    box.restitution = 0.5;
                    try self.bodies.append(box);
                }
            },
            // c.SDL_EVENT_MOUSE_MOTION => {
            //     self.bodies.items[1].position.setX(event.motion.x);
            //     self.bodies.items[1].position.setY(event.motion.y);
            // },
            else => {},
        }
    }
}

pub fn update(self: *Self) void {
    // graphics.clearScreen(0xFF0F0721);

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

        // body.addForce(&force.drag(body, 0.003));
        body.addForce(&force.weight(body, 9.8 * physicsConstants.PIXELS_PER_METER));

        // body.addTorque(200);
        body.update(deltaTime);
    }

    for (self.bodies.items, 0..) |*a, i| {
        for (self.bodies.items[i + 1 ..]) |*b| {
            var contact: collisions.Contact = undefined;
            if (collisions.isColliding(a, b, &contact)) {
                contact.resolveCollision();

                // graphics.drawFillCircle(contact.start.x(), contact.start.y(), 3, 0xFFFF00FF);
                // graphics.drawFillCircle(contact.end.x(), contact.end.y(), 3, 0xFFFF00FF);
                // const normalLineEnd = contact.start.add(&contact.normal.mulScalar(15));
                // graphics.drawLine(contact.start.x(), contact.start.y(), normalLineEnd.x(), normalLineEnd.y(), 0xFFFF00FF);
            }
        }
    }
}

pub fn render(self: *const Self) void {
    graphics.clearScreen(0xFF0F0721);

    for (self.bodies.items) |body| {
        switch (body.shape) {
            .circle => |circle| graphics.drawCircle(body.position.x(), body.position.y(), circle.radius, body.rotation, 0xFFFFFFFF),
            .box => |box| graphics.drawPolygon(body.position.x(), body.position.y(), box.worldVertices.items, 0xFFFFFFFF),
            else => @panic("Shape not supported yet"),
        }
    }

    graphics.renderFrame();
}

pub fn isRunning(self: *const Self) bool {
    return self.running;
}
