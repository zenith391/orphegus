const std = @import("std");
const testing = std.testing;

pub const AudioBuffer = struct {
    samples: []f32,
    sample_rate: u32,

    pub fn init(allocator: std.mem.Allocator, size: usize, sample_rate: u32) !AudioBuffer {
        const samples = try allocator.alloc(f32, size);
        return AudioBuffer{ .samples = samples, .sample_rate = sample_rate };
    }

    pub fn deinit(self: AudioBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.samples);
    }

    pub fn writeAsPCM(self: AudioBuffer, max: u32, writer: anytype) !void {
        // Conversion de tous les floats en entiers
        for (self.samples, 0..) |sample, i| {
            if (i >= max) break;
            std.debug.assert(!std.math.isNan(sample));
            std.debug.assert(std.math.isFinite(sample));
            const byte: i16 = @intFromFloat(@min(1, @max(-1, sample)) * std.math.maxInt(i16));
            // NOTE: c'est potentiellement très très lent d'écrire octet à octet
            try writer.writeInt(i16, byte, .little);
        }
    }
};

// Nodes follow a pull system. That is when one node gets asked to provide a sample, it asks
// all its dependencies to also provide samples. For performance's sake, samples are buffered.
// This system means that not all nodes are at the same time, which means that every node must
// be pure and not depend on external factors.

/// This node adds a delay effect. It takes only one dependency (although it could easily be
/// upgraded to take more than one)
pub const DelayLine = struct {
    // buffer: std.ArrayList(f32),
    /// Delay in seconds
    delay: f32,
    feedback: f32 = 0.0,
    gain: f32 = 1.0,
    do_initial: bool = false,
    node: AudioNode,
    previous_batch: []f32,

    pub fn init(allocator: std.mem.Allocator, delay: f32) DelayLine {
        const line = DelayLine{
            .delay = delay,
            .node = AudioNode.from(DelayLine, allocator),
            .previous_batch = allocator.alloc(f32, @intFromFloat(44100.0 * delay)) catch unreachable,
        };
        @memset(line.previous_batch, 0);
        return line;
    }

    pub fn process(node: *AudioNode, sample_rate: u32, n_samples: usize) void {
        const self: *DelayLine = @fieldParentPtr("node", node);
        const dependency = node.dependencies.items[0];
        const start = node.getLastSampleIndex();
        for (0..n_samples) |i| {
            const offset_float = self.delay * @as(f32, @floatFromInt(sample_rate));
            const offset: usize = @intFromFloat(offset_float);
            if (start + i >= offset) {
                const sample = dependency.consumeSample(sample_rate, start + i - offset);
                const value = sample + self.previous_batch[(start + i) % offset] * self.feedback;
                self.previous_batch[(start + i) % offset] = value;
                node.buffer.appendAssumeCapacity(value * self.gain);
            } else {
                if (self.do_initial) {
                    const sample = dependency.consumeSample(sample_rate, start + i);
                    node.buffer.appendAssumeCapacity(sample);
                } else {
                    node.buffer.appendAssumeCapacity(0);
                }
            }
        }
    }

    pub fn deinit(self: *DelayLine) void {
        // self.buffer.deinit();
        self.node.deinit();
    }
};

/// Implémentation d'un filtre RC passe-bas
/// c.f. https://en.wikipedia.org/wiki/Low-pass_filter
pub const LowPassNode = struct {
    node: AudioNode,
    cutoff: f32,
    last_sample: f32 = 0.0,

    pub fn init(allocator: std.mem.Allocator, cutoff: f32) LowPassNode {
        const low_pass = LowPassNode{
            .node = AudioNode.from(LowPassNode, allocator),
            .cutoff = cutoff,
        };
        return low_pass;
    }

    pub fn process(node: *AudioNode, sample_rate: u32, n_samples: usize) void {
        const self: *LowPassNode = @fieldParentPtr("node", node);
        const start = node.getLastSampleIndex();
        const dependency = node.dependencies.items[0];
        for (0..n_samples) |i| {
            const in_sample = dependency.consumeSample(sample_rate, start + i);
            const dt = 1.0 / @as(f32, @floatFromInt(sample_rate));
            const alpha = 2 * std.math.pi * dt * self.cutoff / (2 * std.math.pi * dt * self.cutoff + 1);
            const out_sample = alpha * in_sample + (1 - alpha) * self.last_sample;
            node.buffer.appendAssumeCapacity(out_sample);
            self.last_sample = out_sample;
        }
    }

    pub fn deinit(self: *LowPassNode) void {
        self.node.deinit();
    }
};

pub const WhiteNoiseNode = struct {
    node: AudioNode,
    prng: std.Random.DefaultPrng,
    stop_time: f32,
    gain: f32 = 1.0,

    pub fn init(allocator: std.mem.Allocator) WhiteNoiseNode {
        const sine_node = WhiteNoiseNode{
            .node = AudioNode.from(WhiteNoiseNode, allocator),
            .prng = std.Random.DefaultPrng.init(0),
            .stop_time = 1.0,
        };
        return sine_node;
    }

    pub fn process(node: *AudioNode, sample_rate: u32, n_samples: usize) void {
        const self: *WhiteNoiseNode = @fieldParentPtr("node", node);
        const start = node.getLastSampleIndex();
        for (0..n_samples) |i| {
            const time = @as(f32, @floatFromInt(start + i)) / @as(f32, @floatFromInt(sample_rate));
            if (time < self.stop_time) {
                const random = self.prng.random();
                var sample = (random.float(f32) * 2 - 1) * self.gain;
                if (sample >= 0) sample = 1.0;
                if (sample < 0) sample = -1.0;
                node.buffer.appendAssumeCapacity(sample);
            } else {
                node.buffer.appendAssumeCapacity(0);
            }
        }
    }

    pub fn deinit(self: *WhiteNoiseNode) void {
        self.node.deinit();
    }
};

pub const SineNode = struct {
    node: AudioNode,
    frequency: f32,
    gain: f32,

    pub fn init(allocator: std.mem.Allocator, frequency: f32) SineNode {
        const sine_node = SineNode{
            .node = AudioNode.from(SineNode, allocator),
            .frequency = frequency,
            .gain = 1.0,
        };
        return sine_node;
    }

    pub fn process(node: *AudioNode, sample_rate: u32, n_samples: usize) void {
        const self: *SineNode = @fieldParentPtr("node", node);
        const start = node.getLastSampleIndex();
        for (0..n_samples) |i| {
            const time = @as(f32, @floatFromInt(start + i)) / @as(f32, @floatFromInt(sample_rate));
            const sample = @sin(2 * std.math.pi * self.frequency * time) * self.gain;
            node.buffer.appendAssumeCapacity(sample);
        }
    }

    pub fn deinit(self: *SineNode) void {
        self.node.deinit();
    }
};

pub const SumNode = struct {
    node: AudioNode,

    pub fn init(allocator: std.mem.Allocator) SumNode {
        const sum_node = SumNode{
            .node = AudioNode.from(SumNode, allocator),
        };
        return sum_node;
    }

    pub fn process(node: *AudioNode, sample_rate: u32, n_samples: usize) void {
        const self: *SumNode = @fieldParentPtr("node", node);
        _ = self;
        const start = node.getLastSampleIndex();
        const dependencies = node.dependencies.items;
        for (0..n_samples) |i| {
            var sample: f32 = 0;
            for (dependencies) |dependency| {
                sample += dependency.consumeSample(sample_rate, start + i);
            }
            node.buffer.appendAssumeCapacity(sample);
        }
    }

    pub fn deinit(self: *SumNode) void {
        self.node.deinit();
    }
};

pub const AudioNode = struct {
    /// The index of the first sample that is in the node's buffer
    first_buffered_sample: usize,
    /// Buffer of samples left for processing
    /// TODO: should it really store an allocator ?
    buffer: std.ArrayList(f32),
    /// TODO: bounded array instead?
    dependencies: std.ArrayList(*AudioNode),
    vtable: *const VTable,

    pub const VTable = struct {
        process: *const fn (*AudioNode, sample_rate: u32, n_samples: usize) void,
        // deinit: *const fn(*AudioNode) void,

        pub fn from(comptime T: type) VTable {
            return .{
                .process = &T.process,
                // .deinit = &T.deinit,
            };
        }
    };

    pub fn from(comptime T: type, allocator: std.mem.Allocator) AudioNode {
        const vtable = comptime VTable.from(T);
        return .{
            .first_buffered_sample = 0,
            .buffer = std.ArrayList(f32).init(allocator),
            .dependencies = std.ArrayList(*AudioNode).init(allocator),
            .vtable = &vtable,
        };
    }

    /// Process a given number of samples.
    pub fn processNSamples(self: *AudioNode, sample_rate: u32, n_samples: usize) void {
        self.vtable.process(self, sample_rate, n_samples);
    }

    /// Process until the specified point in time is reached.
    pub fn processUntil(self: *AudioNode, sample_rate: u32, sample_index: usize) void {
        const last_sample_index = self.first_buffered_sample + self.buffer.items.len;
        if (last_sample_index <= sample_index) {
            self.processNSamples(sample_rate, sample_index - last_sample_index + 1);
        }
    }

    pub fn getSample(self: *AudioNode, sample_index: usize) f32 {
        const index = sample_index - self.first_buffered_sample;
        return self.buffer.items[index];
    }

    pub fn consumeSample(self: *AudioNode, sample_rate: u32, sample_index: usize) f32 {
        if (self.getLastSampleIndex() > sample_index) {
            // std.debug.assert(sample_index == self.first_buffered_sample);
            const sample = self.getSample(sample_index);
            // _ = self.buffer.orderedRemove(0);
            // self.first_buffered_sample += 1;
            return sample;
        } else {
            self.processUntil(sample_rate, sample_index);
            return self.consumeSample(sample_rate, sample_index);
        }
    }

    pub fn getLastSampleIndex(self: *AudioNode) usize {
        return self.first_buffered_sample + self.buffer.items.len;
    }

    pub fn flushToAudioBuffer(self: *AudioNode, start_sample: usize, audio_buffer: AudioBuffer) void {
        const len = audio_buffer.samples.len;
        @memcpy(audio_buffer.samples, self.buffer.items[start_sample .. start_sample + len]);
        // self.first_buffered_sample += len;
        // self.buffer.replaceRange(0, len, &.{}) catch unreachable;
    }

    pub fn reserveSpace(self: *AudioNode, samples: usize) !void {
        if (self.buffer.capacity - self.buffer.items.len < samples) {
            try self.buffer.ensureUnusedCapacity(samples);
            for (self.dependencies.items) |dependency| {
                try dependency.reserveSpace(samples);
            }
        }
    }

    pub fn deinit(self: *AudioNode) void {
        self.buffer.deinit();
        self.dependencies.deinit();
    }
};

/// Duration is expressed in seconds
pub fn exportToWav(node: *AudioNode, duration: f32, writer: anytype) !void {
    // Write the header
    const channels = 1;
    const sample_rate: u32 = 44100; // The sample rate must be an integer

    // The number of frames elapsed since the start
    const total_frames: u32 = @intFromFloat(duration * @as(f32, @floatFromInt(sample_rate)));
    const data_size = total_frames * 2;
    const file_size: u32 = 44 + data_size;

    try writer.print("RIFF", .{});
    try writer.writeInt(u32, file_size - 8, .little);
    try writer.print("WAVE", .{});

    // Data format chunk
    try writer.print("fmt ", .{});
    try writer.writeInt(u32, 16, .little); // chunk size minus 8 bytes
    try writer.writeInt(u16, 1, .little); // audio format is PCM integer
    try writer.writeInt(u16, channels, .little); // one channel only
    try writer.writeInt(u32, sample_rate, .little);
    try writer.writeInt(u32, sample_rate * channels * 2, .little); // bytes per sec
    try writer.writeInt(u16, channels * 2, .little); // bytes per bloc
    try writer.writeInt(u16, 16, .little); // bits per sample

    // Data block
    try writer.print("data", .{});
    try writer.writeInt(u32, data_size, .little);

    var mem_buffer: [128 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&mem_buffer);
    const allocator = fba.allocator();

    var frames: u32 = 0;
    // Buffer size in number of samples
    const buffer_size = 16 * 1024;
    const buffer = try AudioBuffer.init(allocator, buffer_size, sample_rate);
    try node.reserveSpace(total_frames + buffer_size);
    while (frames < total_frames) : (frames += buffer_size) {
        node.processUntil(sample_rate, frames + buffer_size);
        node.flushToAudioBuffer(frames, buffer);
        // audio_process(buffer, time);
        const max = total_frames - frames;
        try buffer.writeAsPCM(max, writer);
    }
}
