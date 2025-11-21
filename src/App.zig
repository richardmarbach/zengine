const std = @import("std");

const graphics = @import("physics/graphics.zig");
const Body = @import("physics/Body.zig");
const physicsConstants = @import("physics/constants.zig");
const shapes = @import("physics/shapes.zig");
const World = @import("physics/World.zig");
const Constraint = @import("physics/constraint.zig");

const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
});

const Vec2 = @import("physics/vec.zig").Vec2(f32);

const Self = @This();

var debug = false;

running: bool = true,
alloc: std.mem.Allocator,
world: World,

timePreviousFrame: u64 = 0,

pub fn init(alloc: std.mem.Allocator) !Self {
    try graphics.openWindow();

    var world = World.init(9.8);

    var floor = Body.init(
        shapes.Shape{ .box = try shapes.Box.init(alloc, graphics.width() - 58, 20) },
        @as(f32, @floatFromInt(graphics.width() / 2)) - 5,
        @as(f32, @floatFromInt(graphics.height())) - 20,
        0.0,
    );
    floor.restitution = 0.7;
    try world.addBody(alloc, floor);

    var leftWall = Body.init(
        shapes.Shape{ .box = try shapes.Box.init(alloc, 20, graphics.height() - 40) },
        10,
        @as(f32, @floatFromInt(graphics.height() / 2)) + 10,
        0.0,
    );
    leftWall.restitution = 0.2;
    try world.addBody(alloc, leftWall);

    var rightWall = Body.init(
        shapes.Shape{ .box = try shapes.Box.init(alloc, 20, graphics.height() - 40) },
        @floatFromInt(graphics.width() - 20),
        @as(f32, @floatFromInt(graphics.height() / 2)) + 10,
        0.0,
    );
    rightWall.restitution = 0.2;
    try world.addBody(alloc, rightWall);

    // var bigBox = Body.init(
    //     shapes.Shape{ .box = try shapes.Box.init(alloc, 100, 100) },
    //     @floatFromInt(graphics.width() / 2),
    //     @floatFromInt(graphics.height() / 2),
    //     0.0,
    // );
    // bigBox.rotation = 0.3;
    // bigBox.setTexture(try graphics.Texture.load("assets/crate.png"));
    // try world.addBody(alloc, bigBox);

    var bigBall = Body.init(
        shapes.Shape{ .circle = shapes.Circle{ .radius = 64 } },
        @floatFromInt(graphics.width() / 2),
        @floatFromInt(graphics.height() / 2),
        0.0,
    );
    bigBall.rotation = 0.3;
    bigBall.setTexture(try graphics.Texture.load("assets/bowlingball.png"));
    try world.addBody(alloc, bigBall);

    return .{
        .alloc = alloc,
        .world = world,
    };
}

pub fn deinit(self: *Self) void {
    self.world.deinit(self.alloc);
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
                    c.SDLK_D => debug = !debug,
                    else => {},
                }
            },
            c.SDL_EVENT_KEY_UP => {
                switch (event.key.key) {
                    c.SDLK_ESCAPE => self.running = false,
                    else => {},
                }
            },
            c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                if (event.button.button == c.SDL_BUTTON_LEFT) {
                    var box = Body.init(
                        shapes.Shape{ .box = try shapes.Box.init(self.alloc, 50, 50) },
                        event.button.x,
                        event.button.y,
                        1.0,
                    );
                    box.restitution = 0.1;
                    try self.world.addBody(self.alloc, box);
                }
                if (event.button.button == c.SDL_BUTTON_RIGHT) {
                    var ball = Body.init(
                        shapes.Shape{ .circle = shapes.Circle{ .radius = 30 } },
                        event.button.x,
                        event.button.y,
                        1.0,
                    );
                    ball.setTexture(graphics.Texture.load("assets/basketball.png") catch null);
                    ball.restitution = 0.5;
                    try self.world.addBody(self.alloc, ball);
                }
            },
            else => {},
        }
    }
}

pub fn update(self: *Self) void {
    if (debug) {
        graphics.clearScreen(0xFF0F0721);
    }

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
    self.world.update(self.alloc, deltaTime) catch {
        std.debug.print("World update error\n", .{});
    };
}

pub fn render(self: *const Self) void {
    if (!debug) {
        graphics.clearScreen(0xFF0F0721);
    }

    for (self.world.bodies.items) |body| {
        switch (body.shape) {
            .circle => |circle| {
                if (!debug and body.texture != null) {
                    const texture = body.texture.?;
                    graphics.drawTexture(
                        body.position.x(),
                        body.position.y(),
                        circle.radius * 2,
                        circle.radius * 2,
                        body.rotation,
                        &texture,
                    );
                } else {
                    graphics.drawCircle(
                        body.position.x(),
                        body.position.y(),
                        circle.radius,
                        body.rotation,
                        0xFFFFFFFF,
                    );
                }
            },
            .box => |box| {
                if (!debug and body.texture != null) {
                    const texture = body.texture.?;
                    graphics.drawTexture(
                        body.position.x(),
                        body.position.y(),
                        @floatFromInt(box.width),
                        @floatFromInt(box.height),
                        body.rotation,
                        &texture,
                    );
                } else {
                    graphics.drawPolygon(
                        body.position.x(),
                        body.position.y(),
                        box.worldVertices.items,
                        0xFFFFFFFF,
                    );
                }
            },
            .polygon => |poly| {
                if (!debug) {
                    graphics.drawFillPolygon(
                        self.alloc,
                        body.position.x(),
                        body.position.y(),
                        poly.worldVertices.items,
                        0xFFFFFFFF,
                    ) catch {
                        graphics.drawPolygon(
                            body.position.x(),
                            body.position.y(),
                            poly.worldVertices.items,
                            0xFFFFFFFF,
                        );
                    };
                } else {
                    graphics.drawPolygon(
                        body.position.x(),
                        body.position.y(),
                        poly.worldVertices.items,
                        0xFFFFFFFF,
                    );
                }
            },
        }
    }

    graphics.renderFrame();
}

pub fn isRunning(self: *const Self) bool {
    return self.running;
}
