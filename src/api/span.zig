const std = @import("std");
const oasis = @import("oasis");

const attribute = @import("./attribute.zig");
const root = @import("./root.zig");

pub const TraceId = struct {
    const Self = @This();

    value: u128,

    pub fn init(v: u128) Self {
        return Self{
            .value = v,
        };
    }

    pub fn random() Self {
        var rng = root.options.rng.random();
        return Self{
            .value = rng.int(u128),
        };
    }

    pub fn invalid() Self {
        return Self{
            .value = 0,
        };
    }

    pub fn fromHex(hex_str: []const u8) !Self {
        // todo validate all lowercase
        std.debug.assert(hex_str.len == 32);
        var bytes: [16]u8 = undefined;
        const out_slice = try std.fmt.hexToBytes(&bytes, hex_str);
        std.debug.assert(out_slice.len == 16);
        return Self.fromBytes(bytes);
    }

    pub fn fromBytes(bytes: [16]u8) Self {
        return Self{
            .value = std.mem.readInt(u128, &bytes, .big),
        };
    }

    pub fn toHex(self: Self) [32]u8 {
        return std.fmt.bytesToHex(self.toBytes(), .lower);
    }

    pub fn toBytes(self: Self) [16]u8 {
        return std.mem.toBytes(std.mem.nativeTo(u128, self.value, .big));
    }

    pub fn asBytes(self: Self) []const u8 {
        return std.mem.asBytes(&self.value);
    }
};

pub const SpanId = struct {
    const Self = @This();

    value: u64,

    pub fn init(v: u64) Self {
        return Self{
            .value = v,
        };
    }

    pub fn random() Self {
        var rng = root.options.rng.random();
        return Self{
            .value = rng.int(u64),
        };
    }

    pub fn invalid() Self {
        return Self{
            .value = 0,
        };
    }

    pub fn fromHex(hex_str: []const u8) !Self {
        // todo validate all lowercase
        std.debug.assert(hex_str.len == 16);
        var bytes: [8]u8 = undefined;
        const out_slice = try std.fmt.hexToBytes(&bytes, hex_str);
        std.debug.assert(out_slice.len == 8);
        return Self.fromBytes(bytes);
    }

    pub fn fromBytes(bytes: [8]u8) Self {
        return Self{
            .value = std.mem.readInt(u64, &bytes, .big),
        };
    }

    pub fn toHex(self: Self) [16]u8 {
        return std.fmt.bytesToHex(self.toBytes(), .lower);
    }

    pub fn toBytes(self: Self) [8]u8 {
        return std.mem.toBytes(std.mem.nativeTo(u64, self.value, .big));
    }

    pub fn asBytes(self: Self) []const u8 {
        return std.mem.asBytes(&self.value);
    }
};

pub const Flags = struct {
    const Self = @This();

    sampled: bool,

    pub fn init() Self {
        return Self{
            .sampled = false,
        };
    }
};

pub const TraceState = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    values: []std.meta.Tuple(&.{ []const u8, []const u8 }),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .values = undefined,
        };
    }
};

pub const SpanContext = struct {
    const Self = @This();

    trace_id: TraceId,
    span_id: SpanId,
    flags: Flags,
    state: TraceState,
    is_remote: bool,

    pub fn init(
        trace_id: TraceId,
        span_id: SpanId,
        flags: Flags,
        state: TraceState,
        is_remote: bool,
    ) Self {
        return Self{
            .trace_id = trace_id,
            .span_id = span_id,
            .flags = flags,
            .state = state,
            .is_remote = is_remote,
        };
    }
};

pub const Kind = enum {
    server,
    client,
    producer,
    consumer,
    internal,
};

pub const Link = struct {
    ctx: SpanContext,
    attrs: []attribute.Attribute,
};

pub const Event = struct {
    name: []const u8,
    timestamp: u64,
    attrs: []const attribute.Attribute,
};

pub const Status = union(enum) {
    unset,
    ok,
    err: []const u8,
};

pub const ParentSpan = union(enum) {
    span: *Span,
    span_ctx: SpanContext,
};

pub const Span = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    name: []const u8,
    ctx: SpanContext,
    parent: ?ParentSpan,
    kind: Kind,
    start: u64,
    end: u64,
    attrs: std.ArrayList(attribute.Attribute),
    links: std.ArrayList(Link),
    events: std.ArrayList(Event),
    status: Status,

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        ctx: SpanContext,
        parent: ?ParentSpan,
        start: u64,
    ) Self {
        return Self{
            .allocator = allocator,

            .name = name,
            .ctx = ctx,
            .parent = parent,
            .kind = Kind.internal,
            .start = start,
            .end = 0,
            .attrs = std.ArrayList(attribute.Attribute).init(allocator),
            .links = std.ArrayList(Link).init(allocator),
            .events = std.ArrayList(Event).init(allocator),
            .status = Status.unset,
        };
    }

    pub fn deinit(self: *Self) void {
        self.attrs.deinit();
        self.links.deinit();
        self.events.deinit();
    }
};

test "TraceId.random" {
    const trace_id1 = TraceId.random();
    const trace_id2 = TraceId.random();
    try std.testing.expect(trace_id1.value != trace_id2.value);
}

test "TraceId.fromHex" {
    const trace_id_and_expected_hexs = [5]struct { TraceId, []const u8 }{
        .{ TraceId.invalid(), "00000000000000000000000000000000" },
        .{ TraceId.init(1), "00000000000000000000000000000001" },
        .{ TraceId.init(10), "0000000000000000000000000000000a" },
        .{ TraceId.init(16), "00000000000000000000000000000010" },
        .{ TraceId.init(3405691582), "000000000000000000000000cafebabe" },
    };

    for (trace_id_and_expected_hexs) |trace_id_and_expected_hex| {
        const expected_trace_id = trace_id_and_expected_hex.@"0";
        const hex = trace_id_and_expected_hex.@"1";
        const trace_id = TraceId.fromHex(hex);
        try std.testing.expectEqual(expected_trace_id, trace_id);
    }
}

test "TraceId.fromBytes" {
    const trace_id_and_expected_bytes = [5]struct { TraceId, [16]u8 }{
        .{ TraceId.invalid(), [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } },
        .{ TraceId.init(1), [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 } },
        .{ TraceId.init(10), [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10 } },
        .{ TraceId.init(16), [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16 } },
        .{ TraceId.init(3405691582), [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 202, 254, 186, 190 } },
    };

    for (trace_id_and_expected_bytes) |trace_id_and_expected_byte| {
        const expected_trace_id = trace_id_and_expected_byte.@"0";
        const bytes = trace_id_and_expected_byte.@"1";
        const trace_id = TraceId.fromBytes(bytes);
        try std.testing.expectEqual(expected_trace_id, trace_id);
    }
}

test "TraceId.toHex" {
    const trace_id_and_expected_hexs = [5]struct { TraceId, []const u8 }{
        .{ TraceId.invalid(), "00000000000000000000000000000000" },
        .{ TraceId.init(1), "00000000000000000000000000000001" },
        .{ TraceId.init(10), "0000000000000000000000000000000a" },
        .{ TraceId.init(16), "00000000000000000000000000000010" },
        .{ TraceId.init(3405691582), "000000000000000000000000cafebabe" },
    };

    for (trace_id_and_expected_hexs) |trace_id_and_expected_hex| {
        const trace_id = trace_id_and_expected_hex.@"0";
        const expected_hex = trace_id_and_expected_hex.@"1";
        try std.testing.expectEqualStrings(expected_hex, &trace_id.toHex());
    }
}

test "TraceId.toBytes" {
    const trace_id_and_expected_bytes = [5]struct { TraceId, [16]u8 }{
        .{ TraceId.invalid(), [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } },
        .{ TraceId.init(1), [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 } },
        .{ TraceId.init(10), [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10 } },
        .{ TraceId.init(16), [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16 } },
        .{ TraceId.init(3405691582), [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 202, 254, 186, 190 } },
    };

    for (trace_id_and_expected_bytes) |trace_id_and_expected_byte| {
        const trace_id = trace_id_and_expected_byte.@"0";
        const expected_bytes = trace_id_and_expected_byte.@"1";
        const bytes = trace_id.toBytes();
        try std.testing.expectEqual(expected_bytes, bytes);
    }
}

test "SpanId.random" {
    const span_id1 = SpanId.random();
    const span_id2 = SpanId.random();
    try std.testing.expect(span_id1.value != span_id2.value);
}

test "SpanId.fromHex" {
    const span_id_and_expected_hexs = [5]struct { SpanId, []const u8 }{
        .{ SpanId.invalid(), "0000000000000000" },
        .{ SpanId.init(1), "0000000000000001" },
        .{ SpanId.init(10), "000000000000000a" },
        .{ SpanId.init(16), "0000000000000010" },
        .{ SpanId.init(3405691582), "00000000cafebabe" },
    };

    for (span_id_and_expected_hexs) |span_id_and_expected_hex| {
        const expected_span_id = span_id_and_expected_hex.@"0";
        const hex = span_id_and_expected_hex.@"1";
        const span_id = SpanId.fromHex(hex);
        try std.testing.expectEqual(expected_span_id, span_id);
    }
}

test "SpanId.fromBytes" {
    const span_id_and_expected_bytes = [5]struct { SpanId, [8]u8 }{
        .{ SpanId.invalid(), [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 } },
        .{ SpanId.init(1), [8]u8{ 0, 0, 0, 0, 0, 0, 0, 1 } },
        .{ SpanId.init(10), [8]u8{ 0, 0, 0, 0, 0, 0, 0, 10 } },
        .{ SpanId.init(16), [8]u8{ 0, 0, 0, 0, 0, 0, 0, 16 } },
        .{ SpanId.init(3405691582), [8]u8{ 0, 0, 0, 0, 202, 254, 186, 190 } },
    };

    for (span_id_and_expected_bytes) |span_id_and_expected_byte| {
        const expected_span_id = span_id_and_expected_byte.@"0";
        const bytes = span_id_and_expected_byte.@"1";
        const span_id = SpanId.fromBytes(bytes);
        try std.testing.expectEqual(expected_span_id, span_id);
    }
}

test "SpanId.toHex" {
    const span_id_and_expected_hexs = [5]struct { SpanId, []const u8 }{
        .{ SpanId.invalid(), "0000000000000000" },
        .{ SpanId.init(1), "0000000000000001" },
        .{ SpanId.init(10), "000000000000000a" },
        .{ SpanId.init(16), "0000000000000010" },
        .{ SpanId.init(3405691582), "00000000cafebabe" },
    };

    for (span_id_and_expected_hexs) |span_id_and_expected_hex| {
        const span_id = span_id_and_expected_hex.@"0";
        const expected_hex = span_id_and_expected_hex.@"1";
        try std.testing.expectEqualStrings(expected_hex, &span_id.toHex());
    }
}

test "SpanId.toBytes" {
    const span_id_and_expected_bytes = [5]struct { SpanId, [8]u8 }{
        .{ SpanId.invalid(), [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 } },
        .{ SpanId.init(1), [8]u8{ 0, 0, 0, 0, 0, 0, 0, 1 } },
        .{ SpanId.init(10), [8]u8{ 0, 0, 0, 0, 0, 0, 0, 10 } },
        .{ SpanId.init(16), [8]u8{ 0, 0, 0, 0, 0, 0, 0, 16 } },
        .{ SpanId.init(3405691582), [8]u8{ 0, 0, 0, 0, 202, 254, 186, 190 } },
    };

    for (span_id_and_expected_bytes) |span_id_and_expected_byte| {
        const span_id = span_id_and_expected_byte.@"0";
        const expected_bytes = span_id_and_expected_byte.@"1";
        const bytes = span_id.toBytes();
        try std.testing.expectEqual(expected_bytes, bytes);
    }
}
