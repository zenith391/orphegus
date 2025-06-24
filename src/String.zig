//! Guitar string model based on the "Numerical Modeling and Sound Synthesis for
//! Articulated String/Fretboard Interaction" paper. One massive assumption the
//! paper makes is that string plucks are perpendicular to the fretboard.
//! Nonetheless, the resulting sound (on demonstration tests) is good enough.
//! This could be called the "Bilbao-Torin" algorithm
const std = @import("std");

/// Value of the transverse displacement of the string in a single polarization
u: []const f32,
params: Parameters,

pub const Parameters = struct {
    /// The length of the sting at rest, in m
    rest_length: f32,
    /// Linear mass density, in kg.m-1
    density: f32,
    /// String tension, in N
    tension: f32,
    /// Young's modulus, in Pa
    young_modulus: f32,
    /// String moment of inertia
    /// It is equal to pi * r^4 / 4 for strings of circular cross-sections
    moment_inertia: f32,
    
    // Loss parameters introduced by the paper for the purposes of this specfic
    // algorithm. They need to be acquired experimentally.
    loss_param_0: f32,
    loss_param_1: f32,
};

pub fn init(allocator: std.mem.Allocator, grid_points: u32, time_step: f32, params: Parameters) String {
    const u = try allocator.alloc(f32, grid_points);
    // const grid_spacing = parameter.rest_length / @as(f32, @floatFromInt(grid_points));
    return .{
        .u = u,
        .params = parameters
    };
}

pub fn deinit(self: String, allocator: std.mem.Allocator) {
    allocator.free(self.u);
}