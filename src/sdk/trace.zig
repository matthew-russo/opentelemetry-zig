pub const DynamicTracerProvider = @import("./trace/DynamicTracerProvider.zig");
pub const SpanProcessor = @import("./trace/SpanProcessor.zig");
pub const SpanExporter = @import("./trace/SpanExporter.zig");

pub const SpanLimits = struct {
    attribute_limits: sdk.AttributeSet.Limits = .{},
    event_count_limit: usize = 128,
    link_count_limit: usize = 128,
    attribute_per_event_count_limit: usize = 128,
    attribute_per_link_count_limit: usize = 128,

    attribute_set_string_table_size: usize = 1024,
    attribute_set_value_table_size: usize = 1024,
};

pub const ReadableSpan = struct {
    ptr: ?*anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        acquire: *const fn (?*anyopaque) void,
        release: *const fn (?*anyopaque) void,
        get_data: *const fn (?*anyopaque) *const SpanRecord,
    };

    pub fn acquire(this: @This()) void {
        return this.vtable.acquire(this.ptr);
    }

    pub fn release(this: @This()) void {
        return this.vtable.release(this.ptr);
    }

    pub fn getData(readable_span: ReadableSpan) *const SpanRecord {
        return readable_span.vtable.get_data(readable_span.ptr);
    }
};

pub const ReadWriteSpan = struct {
    ptr: ?*anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        acquire: *const fn (?*anyopaque) void,
        release: *const fn (?*anyopaque) void,
        writer: *const fn (?*anyopaque) api.trace.Span,
        get_data: *const fn (?*anyopaque) *const SpanRecord,
    };

    pub fn acquire(this: @This()) void {
        return this.vtable.acquire(this.ptr);
    }

    pub fn release(this: @This()) void {
        return this.vtable.release(this.ptr);
    }
};

pub const SpanRecord = struct {
    name: []const u8,
    resource: *const sdk.Resource,
    scope: api.InstrumentationScope,
    context: api.trace.SpanContext,
    parent_context: ?api.trace.SpanContext,
    kind: api.trace.SpanKind,
    start_timestamp: i128,
    end_timestamp: ?i128,
    attributes: sdk.AttributeSet,
    links: std.ArrayListUnmanaged(api.trace.Link),
    dropped_links_count: u32,
    events: std.ArrayListUnmanaged(EventRecord),
    dropped_events_count: u32,
    status: api.trace.Status,

    pub fn reset(this: *@This()) void {
        this.name = "";
        this.scope = .{ .name = "" };
        this.context = .{
            .trace_id = api.trace.TraceId.INVALID,
            .span_id = api.trace.SpanId.INVALID,
            .flags = api.trace.Flags.NONE,
            .state = .{
                .values = &.{},
            },
            .is_remote = false,
        };
        this.parent_context = null;
        this.kind = .unspecified;
        this.start_timestamp = undefined;
        this.end_timestamp = null;
        this.attributes.reset();
        this.links.clearRetainingCapacity();
        this.dropped_links_count = 0;
        this.events.clearRetainingCapacity();
        this.dropped_events_count = 0;
        this.status = .unset;
    }

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        this.attributes.deinit(allocator);
        this.links.deinit(allocator);
        this.events.deinit(allocator);
    }

    pub fn jsonStringify(this: @This(), jw: anytype) !void {
        try jw.beginObject();

        try jw.objectField("name");
        try jw.write(this.name);

        // scope is omitted, as OPTL groups spans by intrumentation scope

        try jw.objectField("traceId");
        try jw.write(this.context.trace_id);

        try jw.objectField("spanId");
        try jw.write(this.context.span_id);

        if (this.parent_context) |parent_context| {
            try jw.objectField("parentSpanId");
            try jw.write(parent_context.span_id);
        }

        try jw.objectField("startTimeUnixNano");
        try jw.write(this.start_timestamp);

        try jw.objectField("endTimeUnixNano");
        try jw.write(this.end_timestamp);

        if (this.attributes.kv.count() > 0) {
            try jw.objectField("attributes");
            try jw.write(this.attributes);
        }
        if (this.attributes.dropped_attribute_count > 0) {
            try jw.objectField("droppedAttributesCount");
            try jw.write(this.attributes.dropped_attribute_count);
        }

        if (this.links.items.len > 0) {
            try jw.objectField("links");
            try jw.write(this.links.items);
        }
        if (this.dropped_links_count > 0) {
            try jw.objectField("droppedLinksCount");
            try jw.write(this.dropped_links_count);
        }

        if (this.events.items.len > 0) {
            try jw.objectField("events");
            try jw.write(this.events.items);
        }
        if (this.dropped_events_count > 0) {
            try jw.objectField("droppedEventsCount");
            try jw.write(this.dropped_events_count);
        }

        if (this.status != .unset) {
            try jw.objectField("status");
            try jw.write(this.status);
        }

        try jw.endObject();
    }

    pub fn format(this: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        if (this.end_timestamp) |end_timestamp| {
            const duration = end_timestamp - this.start_timestamp;
            try writer.print("trace({s}): {s} {}", .{ this.scope.name, this.status, this.name, std.fmt.fmtDuration(@intCast(duration)) });
        } else {
            try writer.print("trace({s}): {s} {} to {?}", .{ this.scope.name, this.status, this.name, this.start_timestamp, this.end_timestamp });
        }

        if (this.attributes.kv.count() > 0) {
            try writer.print(" {}", .{this.attributes});
        }
    }
};

pub const EventRecord = struct {
    name: []const u8,
    timestamp: i128,
    attributes: std.ArrayListUnmanaged(api.Attribute),
};

const api = @import("api");
const sdk = @import("../sdk.zig");
const std = @import("std");
