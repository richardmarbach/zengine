const std = @import("std");
const Vec2 = @import("vec.zig").Vec2(f32);

pub const Vertices = std.ArrayList(Vec2);

pub inline fn edgeAt(vertices: []Vec2, i: usize) Vec2 {
    const nextEdge = if (i + 1 >= vertices.len) 0 else i + 1;
    return vertices[nextEdge].sub(&vertices[i]);
}

pub const Circle = struct {
    radius: f32,

    pub fn init(radius: f32) Circle {
        return Circle{
            .radius = radius,
        };
    }

    pub inline fn radiusW(self: *const Circle, t: type) t {
        return @intFromFloat(self.radius);
    }
};

pub const Polygon = struct {
    localVertices: Vertices,
    worldVertices: Vertices,

    pub fn init(vertices: Vertices) Polygon {
        return Polygon{
            .localVertices = vertices,
            .worldVertices = vertices,
        };
    }

    pub fn deinit(self: *Polygon) void {
        self.localVertices.deinit();
        self.worldVertices.deinit();
    }
};

pub const Box = struct {
    localVertices: Vertices,
    worldVertices: Vertices,
    width: u32,
    height: u32,

    pub fn init(alloc: std.mem.Allocator, width: u32, height: u32) !Box {
        const w: f32 = @floatFromInt(width);
        const h: f32 = @floatFromInt(height);

        var localVertices = try Vertices.initCapacity(alloc, 4);
        try localVertices.append(Vec2.init(-w / 2, -h / 2));
        try localVertices.append(Vec2.init(w / 2, -h / 2));
        try localVertices.append(Vec2.init(w / 2, h / 2));
        try localVertices.append(Vec2.init(-w / 2, h / 2));

        const worldVertices = try localVertices.clone();

        return Box{
            .localVertices = localVertices,
            .worldVertices = worldVertices,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *Box) void {
        self.localVertices.deinit();
        self.worldVertices.deinit();
    }
};

pub const ShapeType = enum {
    circle,
    polygon,
    box,
};

pub const Shape = union(ShapeType) {
    circle: Circle,
    polygon: Polygon,
    box: Box,

    pub fn deinit(self: *Shape) void {
        switch (self.*) {
            .circle => {},
            .polygon => self.polygon.deinit(),
            .box => self.box.deinit(),
        }
    }

    pub fn momentOfInertia(self: *const Shape) f32 {
        return switch (self.*) {
            .circle => |c| return c.radius * c.radius * 0.5,
            .box => |b| return (1.0 / 12.0) * @as(f32, @floatFromInt(b.width * b.width + b.height * b.height)),
            .polygon => 0,
        };
    }

    pub fn updateVertices(self: *Shape, position: *const Vec2, angle: f32) void {
        return switch (self.*) {
            .circle => {},
            .polygon => |p| localToWorldVertices(p.localVertices.items, position, angle, p.worldVertices.items),
            .box => |b| localToWorldVertices(b.localVertices.items, position, angle, b.worldVertices.items),
        };
    }

    fn localToWorldVertices(localVertices: []Vec2, position: *const Vec2, angle: f32, worldVertices: []Vec2) void {
        for (localVertices, 0..) |vertex, i| {
            const worldCordinate = vertex.rotate(angle).add(position);
            worldVertices[i] = worldCordinate;
        }
    }
};
