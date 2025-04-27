const std = @import("std");
const Vec2 = @import("vec.zig").Vec2(f32);

pub const Vertices = std.ArrayList(Vec2);

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
    vertices: Vertices,

    pub fn init(vertices: Vertices) Polygon {
        return Polygon{
            .vertices = vertices,
        };
    }

    pub fn deinit(self: *Polygon) void {
        self.vertices.deinit();
    }
};

pub const Box = struct {
    vertices: Vertices,

    pub fn init(vertices: Vertices) Box {
        return Box{
            .vertices = vertices,
        };
    }

    pub fn deinit(self: *Box) void {
        self.vertices.deinit();
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
        switch (self) {
            .circle => {},
            .polygon => self.polygon.deinit(),
            .box => {},
        }
    }
};
