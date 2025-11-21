const std = @import("std");
const App = @import("App.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        if (gpa.deinit() == .leak) std.debug.assert(false);
    }

    var app = try App.init(allocator);
    defer app.deinit();

    while (app.isRunning()) {
        try app.input();
        app.update();
        app.render();
    }
}

test {
    std.testing.refAllDecls(@This());
}
