const std = @import("std");
const math = std.math;
const builtin = @import("builtin");

const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cInclude("SDL3_image/SDL_image.h");
    @cInclude("SDL3_gfxPrimitives.h");
});

const Vec2 = @import("vec.zig").Vec2(f32);

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
    _ = c.lineColor(
        renderer,
        @intFromFloat(x - w / 2.0),
        @intFromFloat(y - h / 2.0),
        @intFromFloat(x + w / 2.0),
        @intFromFloat(y - h / 2.0),
        color,
    );
    _ = c.lineColor(
        renderer,
        @intFromFloat(x + w / 2.0),
        @intFromFloat(y - h / 2.0),
        @intFromFloat(x + w / 2.0),
        @intFromFloat(y + h / 2.0),
        color,
    );
    _ = c.lineColor(
        renderer,
        @intFromFloat(x + w / 2.0),
        @intFromFloat(y + h / 2.0),
        @intFromFloat(x - w / 2.0),
        @intFromFloat(y + h / 2.0),
        color,
    );
    _ = c.lineColor(
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

pub fn drawPolygon(x: f32, y: f32, vertices: []Vec2, color: u32) void {
    const numVertices = vertices.len;
    if (numVertices == 0) return;

    for (vertices, 0..) |vertex, i| {
        const nextVertex = if (i + 1 < numVertices) vertices[i + 1] else vertices[0];
        _ = c.lineColor(
            renderer,
            @intFromFloat(vertex.x()),
            @intFromFloat(vertex.y()),
            @intFromFloat(nextVertex.x()),
            @intFromFloat(nextVertex.y()),
            color,
        );
    }
    _ = c.filledCircleColor(renderer, @intFromFloat(x), @intFromFloat(y), 1, color);
}

pub fn drawFillPolygon(alloc: std.mem.Allocator, x: f32, y: f32, vertices: []Vec2, color: u32) !void {
    const vx = try alloc.alloc(i16, vertices.len);
    const vy = try alloc.alloc(i16, vertices.len);
    defer alloc.free(vx);
    defer alloc.free(vy);

    for (vertices, 0..) |vertex, i| {
        vx[i] = @intFromFloat(vertex.x());
        vy[i] = @intFromFloat(vertex.y());
    }

    _ = c.filledPolygonColor(renderer, vx.ptr, vy.ptr, @intCast(vertices.len), color);
    _ = c.filledCircleColor(renderer, @intFromFloat(x), @intFromFloat(y), 1, 0xFF000000);
}

pub fn drawTexture(x: f32, y: f32, w: f32, h: f32, rotation: f32, texture: *const Texture) void {
    const destRect: c.SDL_FRect = .{
        .x = x - (w / 2),
        .y = y - (h / 2),
        .w = w,
        .h = h,
    };

    const rotationDeg = rotation * math.deg_per_rad;
    _ = c.SDL_RenderTextureRotated(
        renderer,
        texture.sdlTexture,
        null,
        &destRect,
        rotationDeg,
        null,
        c.SDL_FLIP_NONE,
    );
}

pub fn drawText(x: f32, y: f32, text: [:0]const u8) void {
    _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
    _ = c.SDL_RenderDebugText(renderer, x, y, text);
}

pub fn drawFmtText(x: f32, y: f32, comptime fmt: []const u8, args: anytype) void {
    var text: [512]u8 = undefined;
    const output: [:0]const u8 = std.fmt.bufPrintZ(&text, fmt, args) catch blk: {
        std.debug.print("Failed to fmt: " ++ fmt ++ "\n", args);
        break :blk &[_:0]u8{ 'e', 'r', 'r', 'o', 'r' };
    };
    drawText(x, y, output);
}

pub const Texture = struct {
    sdlTexture: *c.SDL_Texture,

    pub fn load(path: [:0]const u8) !Texture {
        const surface = c.IMG_Load(path) orelse {
            c.SDL_Log("Unable to load image: %s", c.SDL_GetError());
            return error.TextureLoadFailed;
        };
        defer c.SDL_DestroySurface(surface);

        const texture = c.SDL_CreateTextureFromSurface(renderer, surface) orelse {
            c.SDL_Log("Unable to create texture from surface: %s", c.SDL_GetError());
            return error.TextureCreationFailed;
        };

        return .{ .sdlTexture = texture };
    }

    pub fn deinit(self: *Texture) void {
        c.SDL_DestroyTexture(self.sdlTexture);
    }
};
