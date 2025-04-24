const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
});

const std = @import("std");
const Vec2 = @import("physics/vec.zig").Vec2(f32);
const graphics = @import("graphics.zig");
const Particle = @import("physics/Particle.zig");
const physicsConstants = @import("physics/constants.zig");
const force = @import("physics/force.zig");

const Box = struct {
    tl: *Particle,
    tr: *Particle,
    bl: *Particle,
    br: *Particle,
    size: f32,
    diagonal: f32,
    k: f32,
};

const Self = @This();

running: bool = true,
alloc: std.mem.Allocator,
particles: std.ArrayList(Particle),
pushForce: Vec2 = Vec2.init(0, 0),
box: Box,

timePreviousFrame: u64 = 0,

pub fn init(alloc: std.mem.Allocator) !Self {
    try graphics.openWindow();

    var particles = std.ArrayList(Particle).init(alloc);

    const start = Vec2.init(600, 800);
    const size: f32 = 100;

    // Top left
    try particles.append(Particle.init(start.x(), start.y(), 2, 5));
    // Top Right
    try particles.append(Particle.init(start.x() + size, start.y(), 2, 5));
    // Bottom right
    try particles.append(Particle.init(start.x() + size, start.y() + size, 2, 5));
    // Bottom left
    try particles.append(Particle.init(start.x(), start.y() + size, 2, 5));

    return .{
        .alloc = alloc,
        .particles = particles,
        .box = Box{
            .tl = &particles.items[0],
            .tr = &particles.items[1],
            .br = &particles.items[2],
            .bl = &particles.items[3],
            .size = 100,
            .diagonal = @sqrt(100.0 * 100.0 + 100.0 * 100.0),
            .k = 1500,
        },
    };
}

pub fn deinit(self: *Self) void {
    self.particles.deinit();
    graphics.closeWindow();
}

pub fn input(self: *Self) !void {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event)) {
        switch (event.type) {
            c.SDL_EVENT_QUIT => self.running = false,
            c.SDL_EVENT_KEY_DOWN => {
                switch (event.key.key) {
                    c.SDLK_ESCAPE => self.running = false,
                    c.SDLK_UP => self.pushForce.setY(-50 * physicsConstants.PIXELS_PER_METER),
                    c.SDLK_DOWN => self.pushForce.setY(50 * physicsConstants.PIXELS_PER_METER),
                    c.SDLK_LEFT => self.pushForce.setX(-50 * physicsConstants.PIXELS_PER_METER),
                    c.SDLK_RIGHT => self.pushForce.setX(50 * physicsConstants.PIXELS_PER_METER),
                    else => {},
                }
            },
            c.SDL_EVENT_KEY_UP => {
                switch (event.key.key) {
                    c.SDLK_ESCAPE => self.running = false,
                    c.SDLK_UP => self.pushForce.setY(0),
                    c.SDLK_DOWN => self.pushForce.setY(0),
                    c.SDLK_LEFT => self.pushForce.setX(0),
                    c.SDLK_RIGHT => self.pushForce.setX(0),
                    else => {},
                }
            },
            c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                if (event.button.button == c.SDL_BUTTON_LEFT) {
                    try self.particles.append(Particle.init(
                        event.button.x,
                        event.button.y,
                        1,
                        4,
                    ));
                }
            },
            else => {},
        }
    }
}

pub fn update(self: *Self) void {
    if (self.timePreviousFrame + physicsConstants.MS_PER_FRAME > c.SDL_GetTicks()) {
        const timeElapsed = physicsConstants.MS_PER_FRAME - (c.SDL_GetTicks() - self.timePreviousFrame);
        c.SDL_Delay(@truncate(timeElapsed));
    }
    const deltaTime: f32 = deltaTime: {
        const elapsedTicks: f32 = @floatFromInt(c.SDL_GetTicks() - self.timePreviousFrame);
        const deltaTime = elapsedTicks / 1000.0;
        if (deltaTime > 4 * physicsConstants.MS_PER_FRAME) {
            break :deltaTime physicsConstants.MS_PER_FRAME;
        }
        break :deltaTime deltaTime;
    };

    self.timePreviousFrame = c.SDL_GetTicks();

    // right vertical
    const trbr = force.springParticle(self.box.tr, self.box.br, self.box.size, self.box.k);
    self.box.tr.addForce(&trbr);
    self.box.br.addForce(&trbr.negate());

    // left vertical
    const tlbl = force.springParticle(self.box.tl, self.box.bl, self.box.size, self.box.k);
    self.box.tl.addForce(&tlbl);
    self.box.bl.addForce(&tlbl.negate());

    // Bottom horizontal
    const brbl = force.springParticle(self.box.br, self.box.bl, self.box.size, self.box.k);
    self.box.br.addForce(&brbl);
    self.box.bl.addForce(&brbl.negate());

    // Top horizontal
    const trtl = force.springParticle(self.box.tr, self.box.tl, self.box.size, self.box.k);
    self.box.tr.addForce(&trtl);
    self.box.tl.addForce(&trtl.negate());

    // Diagonal
    const tlbr = force.springParticle(self.box.tl, self.box.br, self.box.diagonal, self.box.k);
    self.box.tl.addForce(&tlbr);
    self.box.br.addForce(&tlbr.negate());

    const trbl = force.springParticle(self.box.tr, self.box.bl, self.box.diagonal, self.box.k);
    self.box.tr.addForce(&trbl);
    self.box.bl.addForce(&trbl.negate());

    for (self.particles.items) |*particle| {
        // Push
        particle.addForce(&self.pushForce);

        particle.addForce(&force.drag(particle, 0.003));
        particle.addForce(&force.weight(particle, 9.8 * physicsConstants.PIXELS_PER_METER));

        particle.integrate(deltaTime);

        var bounce = Vec2.init(1, 1);
        const currentX: i32 = @intFromFloat(particle.position.x());
        const currentY: i32 = @intFromFloat(particle.position.y());

        if (currentY > graphics.height() - particle.radius) {
            particle.position.setY(@floatFromInt(graphics.height() - particle.radius * 2));
            bounce.setY(-0.8);
        }
        if (currentY < particle.radius) {
            particle.position.setY(@floatFromInt(particle.radius));
            bounce.setY(-0.8);
        }

        if (currentX > graphics.width() - particle.radius) {
            particle.position.setX(@floatFromInt(graphics.width() - particle.radius));
            bounce.setX(-0.8);
        }
        if (currentX < particle.radius) {
            particle.position.setX(@floatFromInt(particle.radius));
            bounce.setX(-0.8);
        }
        particle.velocity = particle.velocity.mul(&bounce);
    }
}

pub fn render(self: *const Self) void {
    graphics.clearScreen(0xFF3D3D3C);

    for (self.particles.items) |particle| {
        graphics.drawFillCircle(
            particle.position.x(),
            particle.position.y(),
            @floatFromInt(particle.radius),
            0xFFFFFFFF,
        );
    }

    graphics.drawLine(
        self.box.tl.position.x(),
        self.box.tl.position.y(),
        self.box.tr.position.x(),
        self.box.tr.position.y(),
        0xFF6E3712,
    );
    graphics.drawLine(
        self.box.tl.position.x(),
        self.box.tl.position.y(),
        self.box.bl.position.x(),
        self.box.bl.position.y(),
        0xFF6E3712,
    );
    graphics.drawLine(
        self.box.tl.position.x(),
        self.box.tl.position.y(),
        self.box.br.position.x(),
        self.box.br.position.y(),
        0xFF6E3712,
    );
    graphics.drawLine(
        self.box.br.position.x(),
        self.box.br.position.y(),
        self.box.tr.position.x(),
        self.box.tr.position.y(),
        0xFF6E3712,
    );
    graphics.drawLine(
        self.box.br.position.x(),
        self.box.br.position.y(),
        self.box.bl.position.x(),
        self.box.bl.position.y(),
        0xFF6E3712,
    );
    graphics.drawLine(
        self.box.tr.position.x(),
        self.box.tr.position.y(),
        self.box.bl.position.x(),
        self.box.bl.position.y(),
        0xFF6E3712,
    );

    graphics.renderFrame();
}

pub fn isRunning(self: *const Self) bool {
    return self.running;
}
