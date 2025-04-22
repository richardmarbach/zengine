const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
});

const std = @import("std");
const graphics = @import("graphics.zig");

const Self = @This();

running: bool = true,
alloc: std.mem.Allocator,

pub fn init(alloc: std.mem.Allocator) Self {
    return .{ .alloc = alloc };
}

pub fn deinit(_: *Self) void {
    graphics.closeWindow();
}

pub fn setup(_: *Self) !void {
    try graphics.openWindow();
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

pub fn update(_: *Self) void {}

pub fn render(_: *Self) void {
    graphics.clearScreen(0xFF056263);
    graphics.drawFillCircle(200, 200, 40, 0xFFFFFFFF);
    graphics.renderFrame();
}

pub fn isRunning(self: *const Self) bool {
    return self.running;
}
