//! Guitar strings based on a mass-spring system
const std = @import("std");
const String = @This();

/// Values of the transverse displacement of the string in a single polarization
u: []f32,
/// Derivatives of transverse displacement of the string in a single polarization
up: []f32,
/// only used for debugging
upp: []f32,
params: Parameters,

pub const Parameters = struct {
    /// The length of the string at rest, in m
    rest_length: f32,
    /// Linear mass density, in kg.m-1
    density: f32,
    /// String tension, in N
    tension: f32,
    /// String moment of inertia
    /// It is equal to pi * r^4 / 4 for strings of circular cross-sections
    moment_of_inertia: f32,

    springs: u32,
    /// Stiffness of springs
    stiffness: f32,
    /// Friction of springs
    friction: f32,
};

pub fn init(allocator: std.mem.Allocator, params: Parameters) !String {
    const u = try allocator.alloc(f32, params.springs);
    const up = try allocator.alloc(f32, params.springs);
    const upp = try allocator.alloc(f32, params.springs);
    @memset(u, 0.0);
    @memset(up, 0.0);

    return .{
        .u = u,
        .up = up,
        .upp = upp,
        .params = params
    };
}

/// Update using Euler's method
pub fn update(self: *String, time_step: f32) void {
    const l0 = self.params.rest_length / @as(f32, @floatFromInt(self.params.springs));
    const mass = l0 * self.params.density;
    for (0..self.params.springs) |i| {
        // Valeurs de u[i-1] et u[i+1], en considérant que u[-1] = 0 et u[n] = 0
        const prev_u = if (i > 0) self.u[i-1] else 0;
        const next_u = if (i < self.params.springs - 1) self.u[i+1] else 0;

        const friction_force = -self.params.friction * self.up[i];
        const spring_1_force = std.math.sign(prev_u - self.u[i]) * self.params.stiffness
            * (@sqrt(l0 * l0 + @abs(self.u[i] * self.u[i] - prev_u * prev_u)) - l0);
        const spring_2_force = std.math.sign(next_u - self.u[i]) * self.params.stiffness
            * (@sqrt(l0 * l0 + @abs(self.u[i] * self.u[i] - next_u * next_u)) - l0);
        const upp = (friction_force + spring_1_force + spring_2_force) / mass;
        self.upp[i] = upp;
        self.up[i] += upp * time_step;
        self.u[i] += self.up[i] * time_step;
    }
}

pub fn dump(self: String) void {
    std.debug.print("u: {d:.4}\n", .{ self.u });
    // std.debug.print("up: {d}\n", .{ self.up });
    // std.debug.print("upp: {d}\n", .{ self.upp });
}

pub fn deinit(self: String, allocator: std.mem.Allocator) void {
    allocator.free(self.u);
    allocator.free(self.up);
    allocator.free(self.upp);
}