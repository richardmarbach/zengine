const std = @import("std");
// const App = @import("App.zig");
const mat = @import("physics/mat.zig");

pub fn main() !void {
    const r = mat.MatMxN(f32, 3, 3).init(.{
        .{ 1.0, 2.0, 3.0 },
        .{ 4.0, 5.0, 6.0 },
        .{ 7.0, 8.0, 9.0 },
    });
    std.debug.print("Matrix r: {any}\n", .{r.mul(&r)});

    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();
    // defer {
    //     if (gpa.deinit() == .leak) std.debug.assert(false);
    // }
    //
    // var app = try App.init(allocator);
    // defer app.deinit();
    //
    // while (app.isRunning()) {
    //     try app.input();
    //     app.update();
    //     app.render();
    // }
}
