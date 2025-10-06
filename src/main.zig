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

    // Implémentation d'écho très basique
    var reverb_delay_1 = lib.DelayLine.init(allocator, 0.139);
    defer reverb_delay_1.deinit();
    reverb_delay_1.gain = 0.2;
    reverb_delay_1.feedback = 0.2;
    reverb_delay_1.do_initial = true;
    try reverb_delay_1.node.dependencies.append(&sum_node.node);

    var reverb_sum = lib.SumNode.init(allocator);
    defer reverb_sum.deinit();
    try reverb_sum.node.dependencies.append(&reverb_delay_1.node);

    var reverb = lib.LowPassNode.init(allocator, 5000);
    defer reverb.deinit();
    try reverb.node.dependencies.append(&sum_node.node);
    try reverb.node.dependencies.append(&reverb_sum.node);

    try lib.exportToWav(&reverb.node, 5, writer);
}

pub const StringOutputNode = struct {
    node: lib.AudioNode,
    gain: f32 = 1.0,
    /// Time between two simulation steps for the string
    delta: f32 = 0.01,
    string_time: f32 = 0.0,
    string: *String,

    pub fn init(allocator: std.mem.Allocator, string: *String) StringOutputNode {
        const sine_node = StringOutputNode{
            .node = lib.AudioNode.from(StringOutputNode, allocator),
            .string = string,
        };
        return sine_node;
    }

    pub fn process(node: *lib.AudioNode, sample_rate: u32, n_samples: usize) void {
        const self: *StringOutputNode = @fieldParentPtr("node", node);
        const start = node.getLastSampleIndex();
        for (0..n_samples) |i| {
            const time = @as(f32, @floatFromInt(start + i)) / @as(f32, @floatFromInt(sample_rate));
            while (self.string_time <= time) {
                self.string.update(self.delta);
                self.string_time += self.delta;
            }

            const x_idx = self.string.u.len / 10;
            const displacement = self.string.u[x_idx];
            const sample: f32 = @floatCast(displacement * 100);
            if (i == 50) std.log.info("sample: {d}", .{sample});
            node.buffer.appendAssumeCapacity(sample);
        }
    }

    pub fn deinit(self: *StringOutputNode) void {
        self.node.deinit();
    }
};
pub fn springMassModel(allocator: std.mem.Allocator, frequency: f32, writer: anytype) !void {
    _ = frequency;

    var string = try String.init(allocator, .{
        .rest_length = 0.65, // 65 cm at rest
        .density = 0.00075, // 75 g/m, c.f. https://forums.ernieball.com/threads/linear-density-stats-for-power-slinky-strings.59720/
        .tension = 1.0,
        .moment_of_inertia = undefined,
        .stiffness = 4,
        .friction = 0.001,
        .springs = 250,
    });
    defer string.deinit(allocator);

    // On pince le milieu de la corde
    // string.u[string.params.springs / 2] = 0.001;
    for (0..string.params.springs) |i| {
        const amplitude = 0.1;
        const x = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(string.params.springs));
        const oscillations = 20;
        string.u[i] = amplitude * @sin(2 * std.math.pi * oscillations * x);
    }

    var file = try std.fs.cwd().createFile("string_analysis.csv", .{});
    defer file.close();
    const raw_file_writer = file.writer();
    var buf_writer = std.io.bufferedWriter(raw_file_writer);
    const file_writer = buf_writer.writer();

    const DEBUG = false;
    if (DEBUG) {
        const temps = 0.1; // secondes
        const step_size = 0.00001;
        const steps: comptime_int = @intFromFloat(temps / step_size); // nombre d'étapes
        std.log.info("Exécution de {d} étapes", .{steps});
        for (0..steps) |i| {
            if (i % 1000 == 0) std.log.info("TIME AT {d}", .{i});
            // string.dump();
            for (string.u, 0..) |u, j| {
                try file_writer.print("{}", .{u});
                if (j < string.u.len - 1) {
                    try file_writer.print(",", .{});
                }
            }
            try file_writer.writeAll("\n");
            for (string.up, 0..) |u, j| {
                try file_writer.print("{}", .{u});
                if (j < string.u.len - 1) {
                    try file_writer.print(",", .{});
                }
            }
            try file_writer.writeAll("\n");
            string.update(0.0001);
        }
        try buf_writer.flush();
    }

    var output = StringOutputNode.init(allocator, &string);
    output.delta = 0.00001;
    defer output.deinit();

    try lib.exportToWav(&output.node, 5, writer);
}

pub fn main() !void {
    const file = try std.fs.cwd().createFile("output/test.wav", .{});
    defer file.close();

    var buffered = std.io.bufferedWriter(file.writer());
    const writer = buffered.writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const frequency: f32 = 440.0;
    try springMassModel(allocator, frequency, writer);
    try buffered.flush();
}

test "simple test" {}
