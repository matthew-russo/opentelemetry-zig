const std = @import("std");

const attribute = @import("./attribute.zig");

pub const Flags = struct {
    sampled: bool,
};

pub const TraceState = struct {
    values: []std.meta.Tuple(&.{ []const u8, []const u8 }),
};

pub const SpanContext = struct {
    const Self = @This();

    trace_id: [16]u8,
    span_id: [8]u8,
    flags: Flags,
    state: TraceState,
    is_remote: bool,

    pub fn init(trace_id: [16]u8, span_id: [8]u8, flags: Flags, state: TraceState, is_remote: bool) Self {
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
    Server,
    Client,
    Producer,
    Consumer,
    Internal,
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
    Unset,
    Ok,
    Error: []const u8,
};

pub const Span = struct {
    name: []const u8,
    ctx: SpanContext,
    parent: ?*Span,
    kind: Kind,
    start: u64,
    end: u64,
    attrs: []attribute.Attribute,
    links: []const Link,
    events: []const Event,
    status: Status,
};
