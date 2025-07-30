const std = @import("std");
// const App = @import("App.zig");
const mat = @import("physics/mat.zig");

pub fn main() !void {
    const r = mat.MatMxN(f32, 3, 2).init(.{
        .{ 1.0, 2.0 },
        .{ 4.0, 5.0 },
        .{ 7.0, 8.0 },
    });
    const o = mat.MatMxN(f32, 2, 3).init(.{
        .{ 1.0, 2.0, 3.0 },
        .{ 4.0, 5.0, 6.0 },
    });

    std.debug.print("Matrix r: {any}\n", .{r});
    // std.debug.print("Transposed r: {any}\n", .{r.transpose()});
    std.debug.print("Other o: {any}\n", .{o});
    std.debug.print("Generic Multiplication r: {any}\n", .{r.mulM(&o)});

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
