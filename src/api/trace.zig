const trace = @This();

pub const TracerProvider = fn (comptime api.InstrumentationScope) Tracer;

pub const getTracer: TracerProvider = api.options.tracer_provider;

pub const contextExtractSpan = api.options.context_extract_span;
pub const contextWithSpan = api.options.context_with_span;

pub const ContextExtractSpanFn = *const fn (context: *const api.Context) ?api.trace.Span;
pub const ContextWithSpanFn = *const fn (context: *const api.Context, span: api.trace.Span) api.Context;

pub const Tracer = struct {
    ptr: ?*anyopaque,
    vtable: ?*const VTable,

    pub const NULL = Tracer{ .ptr = null, .vtable = null };

    pub const VTable = struct {
        create_span: *const fn (?*anyopaque, name: []const u8, context: ?*const api.Context, options: CreateSpanOptions) Span,
        enabled: *const fn (?*anyopaque, Tracer.EnabledOptions) bool,
    };

    pub const CreateSpanOptions = struct {
        kind: SpanKind = .internal,
        attributes: []const api.Attribute = &.{},
        links: []const Link = &.{},
        start_timestamp: ?i128 = null,
    };
    pub fn createSpan(tracer: Tracer, name: []const u8, context: ?*const api.Context, options: CreateSpanOptions) Span {
        const vtable = tracer.vtable orelse return Span.NULL;
        return vtable.create_span(tracer.ptr, name, context, options);
    }

    /// No options at the moment, but some may be added in the future.
    pub const EnabledOptions = struct {};
    pub fn enabled(tracer: Tracer, options: EnabledOptions) bool {
        const vtable = tracer.vtable orelse return false;
        return vtable.enabled(tracer.ptr, options);
    }
};

pub const Span = struct {
    ptr: ?*anyopaque,
    vtable: ?*const Span.VTable,

    pub const NULL = .{ .ptr = null, .vtable = null };

    pub const VTable = struct {
        get_context: *const fn (?*anyopaque) SpanContext,
        is_recording: *const fn (?*anyopaque) bool,
        set_attribute: *const fn (?*anyopaque, attribute: api.Attribute) void,
        add_event: *const fn (?*anyopaque, AddEventOptions) void,
        add_link: *const fn (?*anyopaque, link: Link) void,
        set_status: *const fn (?*anyopaque, Status) void,
        update_name: *const fn (?*anyopaque, new_name: []const u8) void,
        end: *const fn (?*anyopaque, timestamp: ?i128) void,
        record_exception: *const fn (?*anyopaque, anyerror, ?std.builtin.StackTrace) void,
    };

    pub fn getContext(span: Span) Span.Context {
        if (span.vtable) |vtable| {
            return vtable.get_context(span.ptr);
        }
        return Span.Context.INVALID;
    }

    pub fn end(span: Span, timestamp: ?i128) void {
        if (span.vtable) |vtable| {
            vtable.end(span.ptr, timestamp);
        }
    }
};

pub const SpanKind = enum(u32) {
    unspecified = 0,
    internal = 1,
    server = 2,
    client = 3,
    producer = 4,
    consumer = 5,
};

pub const AddEventOptions = struct {
    name: []const u8,
    timestamp: ?u64 = null,
    attrs: []const api.Attribute = &.{},
};

pub const Status = union(Code) {
    unset,
    ok,
    @"error": []const u8,

    pub const Code = enum(u2) {
        unset = 0,
        ok = 1,
        @"error" = 2,
    };

    pub fn jsonStringify(this: @This(), jw: anytype) !void {
        switch (this) {
            .unset,
            .ok,
            => {
                try jw.beginObject();
                try jw.objectField("code");
                try jw.write(@intFromEnum(@as(Code, this)));
                try jw.endObject();
            },
            .@"error" => |msg| {
                try jw.beginObject();
                try jw.objectField("message");
                try jw.write(msg);
                try jw.objectField("code");
                try jw.write(@intFromEnum(@as(Code, this)));
                try jw.endObject();
            },
        }
    }

    pub fn format(this: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll(@tagName(this));
        switch (this) {
            .unset,
            .ok,
            => {},
            .@"error" => |msg| try writer.print("\"{}\"", .{std.zig.fmtEscapes(msg)}),
        }
    }
};

pub const SpanContext = struct {
    trace_id: TraceId,
    span_id: SpanId,
    flags: trace.Flags,
    state: trace.State,
    is_remote: bool,

    pub const INVALID = SpanContext{
        .trace_id = TraceId.INVALID,
        .span_id = SpanId.INVALID,
        .flags = Flags.NONE,
        .state = .{ .values = &.{} },
        .is_remote = false,
    };

    pub fn isValid(this: @This()) bool {
        return this.trace_id.isValid() and this.span_id.isValid();
    }
};

/// W3C Trace Context trace-id
pub const TraceId = struct {
    bytes: [16]u8,

    pub const INVALID = @This(){ .bytes = [_]u8{0} ** 16 };

    pub fn hex(hex_string: *const [32]u8) @This() {
        var trace_id: @This() = undefined;
        const decoded = std.fmt.hexToBytes(&trace_id.bytes, hex_string) catch @panic("we specified the size of the string, and it should match exactly");
        std.debug.assert(decoded.len == trace_id.bytes.len);
        return trace_id;
    }

    pub fn isValid(this: @This()) bool {
        return !std.mem.allEqual(u8, &this.bytes, 0);
    }

    pub fn jsonStringify(this: *const @This(), jw: anytype) !void {
        try jw.print("\"{}\"", .{std.fmt.fmtSliceHexLower(&this.bytes)});
    }
};

pub const SpanId = struct {
    bytes: [8]u8,

    pub const INVALID = SpanId{ .bytes = [_]u8{0} ** 8 };

    pub fn hex(hex_string: *const [16]u8) SpanId {
        var trace_id: SpanId = undefined;
        const decoded = std.fmt.hexToBytes(&trace_id.bytes, hex_string) catch @panic("we specified the size of the string, and it should match exactly");
        std.debug.assert(decoded.len == trace_id.bytes.len);
        return trace_id;
    }

    pub fn isValid(this: @This()) bool {
        return !std.mem.allEqual(u8, &this.bytes, 0);
    }

    pub fn jsonStringify(this: *const @This(), jw: anytype) !void {
        try jw.print("\"{}\"", .{std.fmt.fmtSliceHexLower(&this.bytes)});
    }
};

/// W3C Trace Context trace-flags
pub const Flags = packed struct(u8) {
    sampled: bool,
    _reserved: u7 = 0,

    pub const NONE = .{ .sampled = false };
    pub const SAMPLED = .{ .sampled = true };
};

pub const State = struct {
    values: []const std.meta.Tuple(&.{ []const u8, []const u8 }),
};

pub const Link = struct {
    ctx: SpanContext,
    attrs: []api.Attribute,
};

pub fn voidTracerProvider(comptime instrumentation_scope: api.InstrumentationScope) Tracer {
    _ = instrumentation_scope;
    return Tracer.NULL;
}

pub fn voidContextExtractSpan(context: *const api.Context) ?api.trace.Span {
    _ = context;
    return Span.NULL;
}
pub fn voidContextWithSpan(context: *const api.Context, span: api.trace.Span) api.Context {
    _ = span;
    return context.*;
}

const api = @import("../api.zig");
const std = @import("std");
