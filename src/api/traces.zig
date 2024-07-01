const std = @import("std");

const attribute = @import("../attribute.zig");
const context = @import("../context.zig");

var global_trace_provider: ?TracerProvider = null;

pub fn setDefaultTracerProvider(tracer_provider: TracerProvider) void {
    global_trace_provider = tracer_provider;
}

pub fn unsetDefaultTracerProvider() void {
    global_trace_provider = null;
}

pub fn getDefaultTracerProvider() ?*TracerProvider {
    return &global_trace_provider;
}

pub const TracerProvider = struct {
    const Self = @This();

    ptr: *anyopaque,

    getTracerFn: *const fn (
        *anyopaque,
        []const u8,
        ?[]const u8,
        ?[]const u8,
        []attribute.Attribute,
    ) Tracer,

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
        if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

        const gen = struct {
            pub fn getTracerImpl(
                pointer: *anyopaque,
                name: []const u8,
                version: ?[]const u8,
                schema_url: ?[]const u8,
                attributes: []attribute.Attribute,
            ) Tracer {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.getTracer, .{ self, name, version, schema_url, attributes });
            }
        };

        return .{
            .ptr = ptr,
            .getTracerFn = gen.getTracerImpl,
        };
    }

    pub fn getTracer(
        self: *Self,
        name: []const u8,
        version: ?[]const u8,
        schema_url: ?[]const u8,
        attributes: []attribute.Attribute,
    ) Tracer {
        return self.getTracerFn(self.ptr, name, version, schema_url, attributes);
    }
};

pub const Tracer = struct {
    const Self = @This();

    ptr: *anyopaque,

    createSpanFn: *const fn (
        *anyopaque,
        []const u8,
        ?context.Context,
        ?Kind,
        []attribute.Attribute,
        []Link,
        ?u64,
    ) Span,

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
        if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

        const gen = struct {
            pub fn createSpanImpl(
                pointer: *anyopaque,
                name: []const u8,
                ctx: ?context.Context,
                kind: ?Kind,
                attrs: []attribute.Attribute,
                links: []Link,
                start: ?u64,
            ) Span {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.createSpan, .{
                    self,
                    name,
                    ctx,
                    kind,
                    attrs,
                    links,
                    start,
                });
            }
        };

        return .{
            .ptr = ptr,
            .createSpanFn = gen.createSpanImpl,
        };
    }

    pub fn createSpan(
        self: *Self,
        name: []const u8,
        ctx: ?context.Context,
        kind: ?Kind,
        attrs: []attribute.Attribute,
        links: []Link,
        start: ?u64,
    ) void {
        return self.createSpanFn(
            self.ptr,
            name,
            ctx,
            kind,
            attrs,
            links,
            start,
        );
    }
};

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

// TODO [matthew-russo 03-23-24] this should be an interface
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
