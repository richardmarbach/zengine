const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cInclude("SDL3_gfxPrimitives.h");
});

const std = @import("std");
const math = std.math;
const Vec2 = @import("physics/vec.zig").Vec2(f32);

const builtin = @import("builtin");
const native_endian = builtin.cpu.arch.endian();

var windowWidth: u32 = 0;
var windowHeight: u32 = 0;
var window: *c.SDL_Window = undefined;
var renderer: *c.SDL_Renderer = undefined;

pub fn width() u32 {
    return windowWidth;
}

pub fn height() u32 {
    return windowHeight;
}

pub fn openWindow() !void {
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    errdefer c.SDL_Quit();

    const displayMode = c.SDL_GetCurrentDisplayMode(1);

    window = c.SDL_CreateWindow(null, displayMode.*.w, displayMode.*.h, c.SDL_WINDOW_BORDERLESS) orelse {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    errdefer c.SDL_DestroyWindow(window);

    renderer = c.SDL_CreateRenderer(window, null) orelse {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    windowWidth = @bitCast(displayMode.*.w);
    windowHeight = @bitCast(displayMode.*.h);
}

pub fn closeWindow() void {
    c.SDL_DestroyRenderer(renderer);
    c.SDL_DestroyWindow(window);
    c.SDL_Quit();
}

pub fn clearScreen(color: u32) void {
    var colors: [4]u8 = undefined;
    std.mem.writeInt(u32, &colors, color, native_endian);
    _ = c.SDL_SetRenderDrawColor(renderer, colors[0], colors[1], colors[2], 255);
    _ = c.SDL_RenderClear(renderer);
}

pub fn renderFrame() void {
    _ = c.SDL_RenderPresent(renderer);
}

pub fn drawLine(x0: f32, y0: f32, x1: f32, y1: f32, color: u32) void {
    _ = c.lineColor(
        renderer,
        @intFromFloat(x0),
        @intFromFloat(y0),
        @intFromFloat(x1),
        @intFromFloat(y1),
        color,
    );
}

pub fn drawCircle(x: f32, y: f32, radius: f32, angle: f32, color: u32) void {
    _ = c.circleColor(
        renderer,
        @intFromFloat(x),
        @intFromFloat(y),
        @intFromFloat(radius),
        color,
    );
    _ = c.lineColor(
        renderer,
        @intFromFloat(x),
        @intFromFloat(y),
        @intFromFloat(x + @cos(angle) * radius),
        @intFromFloat(y + @sin(angle) * radius),
        color,
    );
}

pub fn drawFillCircle(x: f32, y: f32, radius: f32, color: u32) void {
    _ = c.filledCircleColor(
        renderer,
        @intFromFloat(x),
        @intFromFloat(y),
        @intFromFloat(radius),
        color,
    );
}

pub fn drawRect(x: f32, y: f32, w: f32, h: f32, color: u32) void {
    c.lineColor(
        renderer,
        @intFromFloat(x - w / 2.0),
        @intFromFloat(y - h / 2.0),
        @intFromFloat(x + w / 2.0),
        @intFromFloat(y - h / 2.0),
        color,
    );
    c.lineColor(
        renderer,
        @intFromFloat(x + w / 2.0),
        @intFromFloat(y - h / 2.0),
        @intFromFloat(x + w / 2.0),
        @intFromFloat(y + h / 2.0),
        color,
    );
    c.lineColor(
        renderer,
        @intFromFloat(x + w / 2.0),
        @intFromFloat(y + h / 2.0),
        @intFromFloat(x - w / 2.0),
        @intFromFloat(y + h / 2.0),
        color,
    );
    c.lineColor(
        renderer,
        @intFromFloat(x - w / 2.0),
        @intFromFloat(y + h / 2.0),
        @intFromFloat(x - w / 2.0),
        @intFromFloat(y - h / 2.0),
        color,
    );
}

pub fn drawFillRect(x: f32, y: f32, w: f32, h: f32, color: u32) void {
    _ = c.boxColor(
        renderer,
        @intFromFloat(x - w / 2.0),
        @intFromFloat(y - h / 2.0),
        @intFromFloat(x + w / 2.0),
        @intFromFloat(y + h / 2.0),
        color,
    );
}

pub fn drawTexture(x: f32, y: f32, w: f32, h: f32, rotation: f32, texture: *c.SDL_Texture) void {
    const destRect: c.SDL_Rect = .{
        x - (w / 2),
        y - (h / 2),
        w,
        h,
    };

    const rotationDeg = rotation * math.deg_per_rad;
    _ = c.SDL_RenderTextureRotated(renderer, texture, null, &destRect, rotationDeg, null, c.SDL_FLIP_NONE);
}
