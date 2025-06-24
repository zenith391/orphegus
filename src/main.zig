const std = @import("std");
const lib = @import("synthesis");

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
    
    try lib.exportToWav(&reverb.node, 5, writer);
}

pub fn main() !void {
    const file = try std.fs.cwd().createFile("test.wav", .{});
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
