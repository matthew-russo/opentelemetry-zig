const trace = @This();

pub const getTracer = api.options.tracer_provider.getTracer;
pub const Tracer = api.options.tracer_provider.Tracer;

pub const contextExtractSpan = api.options.tracer_provider.contextExtractSpan;
pub const contextWithSpan = api.options.tracer_provider.contextWithSpan;

// pub const contextExtractSpan(context: *const api.Context) ?api.trace.Span {
//     const impl_span = context.getValue(*Span) orelse return null;
//     return impl_span.span();
// }

// pub fn contextWithSpan(context: *const api.Context, span: api.trace.Span) ?api.trace.Span {
//     if (span.vtable != &Span.SPAN_VTABLE) return null;
//     return context.withValue(*Span, @ptrCast(span.ptr));
// }

pub const Span = struct {
    ptr: ?*anyopaque,
    vtable: ?*const Span.VTable,

    pub const @"null" = .{ .ptr = null, .vtable = null };

    pub const VTable = struct {
        get_context: *const fn (Span) SpanContext,
        is_recording: *const fn (Span) bool,
        set_attribute: *const fn (Span, attribute: api.Attribute) void,
        add_event: *const fn (Span, AddEventOptions) void,
        add_link: *const fn (Span, link: Link) void,
        set_status: *const fn (Span, Status) void,
        update_name: *const fn (Span, new_name: []const u8) void,
        end: *const fn (Span, timestamp: ?i128) void,
        record_exception: *const fn (Span, anyerror, ?std.builtin.StackTrace) void,
    };

    pub fn getContext(span: Span) Span.Context {
        if (span.vtable) |vtable| {
            return vtable.get_context(span);
        }
        return Span.Context.INVALID;
    }

    pub fn end(span: Span, timestamp: ?i128) void {
        if (span.vtable) |vtable| {
            vtable.end(span, timestamp);
        }
    }
};

pub const CreateSpanOptions = struct {
    kind: SpanKind = .internal,
    attributes: []const api.Attribute = &.{},
    links: []const Link = &.{},
    start_timestamp: ?i128 = null,
};

/// No options at the moment, but some may be added in the future.
pub const EnabledOptions = struct {};

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

pub const VoidTracerProvider = struct {
    pub fn getTracer(comptime instrumentation_scope: api.InstrumentationScope) VoidTracerProvider.Tracer {
        _ = instrumentation_scope;
        return .{};
    }

    pub const Tracer = struct {
        pub fn createSpan(_: @This(), _: []const u8, _: ?api.Context, _: CreateSpanOptions) Span {
            return Span.null;
        }
        pub fn enabled(_: @This(), _: EnabledOptions) bool {
            return false;
        }
    };
};

const api = @import("../api.zig");
const std = @import("std");
