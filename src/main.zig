const std = @import("std");
const lib = @import("synthesis");
const String = @import("SimplifiedString.zig");

pub fn karplusStrong(allocator: std.mem.Allocator, frequency: f32, writer: anytype) !void {
    var noise_node = lib.WhiteNoiseNode.init(allocator);
    noise_node.gain = 0.5;
    noise_node.stop_time = 1.0 / frequency;
    defer noise_node.deinit();
    
    var sum_node = lib.SumNode.init(allocator);
    defer sum_node.deinit();

    var delay_line = lib.DelayLine.init(allocator, 1.0 / frequency);
    defer delay_line.deinit();
    
    var low_pass = lib.LowPassNode.init(allocator, 8000);
    try low_pass.node.dependencies.append(&delay_line.node);
    defer low_pass.deinit();
    
    try sum_node.node.dependencies.append(&low_pass.node);
    try sum_node.node.dependencies.append(&noise_node.node);
    try delay_line.node.dependencies.append(&sum_node.node);
    
    // Réverbération
    var reverb_delay_1 = lib.DelayLine.init(allocator, 0.139);
    defer reverb_delay_1.deinit();
    reverb_delay_1.gain = 0.2;
    reverb_delay_1.feedback = 0.2;
    reverb_delay_1.do_initial = true;
    try reverb_delay_1.node.dependencies.append(&sum_node.node);

    // var reverb_delay_2 = lib.DelayLine.init(allocator, 0.1138);
    // defer reverb_delay_2.deinit();
    // reverb_delay_2.gain = 0.02;
    // reverb_delay_2.feedback = 0.5;
    // try reverb_delay_2.node.dependencies.append(&sum_node.node);

    // var reverb_delay_3 = lib.DelayLine.init(allocator, 0.00234);
    // defer reverb_delay_3.deinit();
    // reverb_delay_3.gain = 0.05;
    // reverb_delay_3.feedback = 0.99;
    // try reverb_delay_3.node.dependencies.append(&sum_node.node);
    
    var reverb_sum = lib.SumNode.init(allocator);
    defer reverb_sum.deinit();
    try reverb_sum.node.dependencies.append(&reverb_delay_1.node);
    // try reverb_sum.node.dependencies.append(&reverb_delay_2.node);
    // try reverb_sum.node.dependencies.append(&reverb_delay_3.node);
    
    var reverb = lib.LowPassNode.init(allocator, 5000);
    defer reverb.deinit();
    // try reverb.node.dependencies.append(&sum_node.node);
    try reverb.node.dependencies.append(&reverb_sum.node);
    
    var string = try String.init(allocator, .{
        .rest_length = 0.65, // 65 cm at rest
        .density = 0.00075, // 75 g/m, c.f. https://forums.ernieball.com/threads/linear-density-stats-for-power-slinky-strings.59720/
        .tension = 1.0,
        .moment_of_inertia = undefined,
        .stiffness = 4,
        .friction = 0.00001,
        .springs = 250,
    });
    defer string.deinit(allocator);
    
    // On pince le milieu de la corde
    // string.u[string.params.springs / 2] = 0.001;
    for (0..string.params.springs) |i| {
        const amplitude = 0.01;
        const x = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(string.params.springs));
        string.u[i] = amplitude * @sin(2 * std.math.pi * 2 * x);
    }
    
    var file = try std.fs.cwd().createFile("string_analysis.csv", .{ });
    defer file.close();
    const raw_file_writer = file.writer();
    var buf_writer = std.io.bufferedWriter(raw_file_writer);
    const file_writer = buf_writer.writer();
    for (0..10000) |i| {
        if (i % 1000 == 0) std.log.info("TIME AT {d}", .{i});
        // string.dump();
        for (string.u, 0..) |u, j| {
            try file_writer.print("{}", .{ u });
            if (j < string.u.len - 1) {
                try file_writer.print(",", .{});
            }
        }
        try file_writer.writeAll("\n");
        string.update(0.0001);
    }
    try buf_writer.flush();
    
    try lib.exportToWav(&reverb.node, 5, writer);
}

pub fn main() !void {
    const file = try std.fs.cwd().createFile("output/test.wav", .{});
    defer file.close();
    
    var buffered = std.io.bufferedWriter(file.writer());
    const writer = buffered.writer();
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    defer _ = gpa.deinit();
    
    const allocator = gpa.allocator();

    const frequency: f32 = 440.0;
    try karplusStrong(allocator, frequency, writer);
    try buffered.flush();
}

test "simple test" {
}
