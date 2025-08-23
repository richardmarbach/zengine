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

    // Takes ownership of vertices
    pub fn init(vertices: Vertices) !Polygon {
        return Polygon{
            .localVertices = vertices,
            .worldVertices = try vertices.clone(),
        };
    }

    pub fn deinit(self: *Polygon, alloc: std.mem.Allocator) void {
        self.localVertices.deinit(alloc);
        self.worldVertices.deinit(alloc);
    }

    pub fn initEquilateral(alloc: std.mem.Allocator, size: f32, sides: usize) !Polygon {
        var vertices = try Vertices.initCapacity(alloc, sides);

        const angle = std.math.tau / @as(f32, @floatFromInt(sides));

        for (0..sides) |i| {
            const alpha = angle * @as(f32, @floatFromInt(i));
            vertices.appendAssumeCapacity(Vec2.init(
                size * @cos(alpha),
                size * @sin(alpha),
            ));
        }

        return try Polygon.init(vertices);
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
        localVertices.appendAssumeCapacity(Vec2.init(-w / 2, -h / 2));
        localVertices.appendAssumeCapacity(Vec2.init(w / 2, -h / 2));
        localVertices.appendAssumeCapacity(Vec2.init(w / 2, h / 2));
        localVertices.appendAssumeCapacity(Vec2.init(-w / 2, h / 2));

        const worldVertices = try localVertices.clone(alloc);

        return Box{
            .localVertices = localVertices,
            .worldVertices = worldVertices,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *Box, alloc: std.mem.Allocator) void {
        self.localVertices.deinit(alloc);
        self.worldVertices.deinit(alloc);
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

    pub fn deinit(self: *Shape, alloc: std.mem.Allocator) void {
        switch (self.*) {
            .circle => {},
            .polygon => self.polygon.deinit(alloc),
            .box => self.box.deinit(alloc),
        }
    }

    pub fn momentOfInertia(self: *const Shape) f32 {
        return switch (self.*) {
            .circle => |c| return c.radius * c.radius * 0.5,
            .box => |b| return (1.0 / 12.0) * @as(f32, @floatFromInt(b.width * b.width + b.height * b.height)),
            .polygon => 5000, // TODO: do this properly
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
        for (localVertices, worldVertices) |local, *worldVertex| {
            worldVertex.* = local.rotate(angle).add(position);
        }
    }
};
