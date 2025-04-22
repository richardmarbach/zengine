const std = @import("std");
const App = @import("App.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        if (gpa.deinit() == .leak) std.debug.assert(false);
    }

    var app = App.init(allocator);
    defer app.deinit();

    try app.setup();

    while (app.isRunning()) {
        app.input();
        app.update();
        app.render();
    }
}
