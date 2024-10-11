const TracerProvider = @This();

allocator: std.mem.Allocator,
resource: sdk.Resource,
limits: sdk.trace.SpanLimits,
free_spans: std.SinglyLinkedList(Span),
span_processors: []const sdk.trace.SpanProcessor,
tracers: std.ArrayListUnmanaged(*Tracer),

pub const InitOptions = struct {
    resource: sdk.Resource,
    span_processors: []const sdk.trace.SpanProcessor,
    limits: sdk.trace.SpanLimits = .{},
    span_attribute_set_string_table_size: usize = 1024,
    span_attribute_set_value_table_size: usize = 1024,
    preallocated_span_count: usize = 128,
};

pub fn init(allocator: std.mem.Allocator, options: InitOptions) !*@This() {
    const this = try allocator.create(@This());
    errdefer allocator.destroy(this);

    this.* = .{
        .allocator = allocator,
        .resource = options.resource,
        .limits = options.limits,
        .free_spans = .{},
        .span_processors = options.span_processors,
        .tracers = .{},
    };

    errdefer {
        while (this.free_spans.popFirst()) |node| {
            node.data.record.deinit(this.allocator);
            this.allocator.destroy(node);
        }
    }
    for (0..options.preallocated_span_count) |_| {
        this.free_spans.prepend(try this.allocateSpan());
    }

    return this;
}

pub fn getTracer(this: *@This(), comptime scope: api.InstrumentationScope) api.trace.Tracer {
    this.tracers.ensureUnusedCapacity(this.allocator, 1) catch return api.trace.Tracer.NULL;
    const tracer = this.allocator.create(Tracer) catch return api.trace.Tracer.NULL;
    errdefer tracer.shutdown();
    tracer.* = .{
        .provider = this,
        .instrumentation_scope = scope,
    };

    this.tracers.appendAssumeCapacity(tracer);

    return tracer.tracer();
}

pub fn shutdown(this: *@This()) void {
    for (this.span_processors) |processor| {
        processor.shutdown();
    }
    for (this.tracers.items) |tracer| {
        this.allocator.destroy(tracer);
    }
    while (this.free_spans.popFirst()) |node| {
        node.data.record.deinit(this.allocator);
        this.allocator.destroy(node);
    }
    this.tracers.deinit(this.allocator);
    this.allocator.destroy(this);
}

fn allocateSpan(this: *@This()) !*std.SinglyLinkedList(Span).Node {
    const node = try this.allocator.create(std.SinglyLinkedList(Span).Node);
    node.* = .{
        .next = null,
        .data = .{
            .provider = this,
            .reference_count = 0,
            .record = undefined,
        },
    };
    node.data.record.attributes = .{};
    node.data.record.links = .{};
    node.data.record.events = .{};

    try node.data.record.attributes.ensureTotalCapacity(this.allocator, this.limits.attribute_limits);
    try node.data.record.links.ensureTotalCapacity(this.allocator, this.limits.link_count_limit);
    try node.data.record.events.ensureTotalCapacity(this.allocator, this.limits.event_count_limit);

    return node;
}

pub fn contextExtractSpan(context: *const api.Context) ?api.trace.Span {
    const impl_span = context.getValue(*Span) orelse return null;
    return impl_span.span();
}

pub fn contextWithSpan(context: *const api.Context, span: api.trace.Span) api.Context {
    if (span.vtable != Span.SPAN_VTABLE) return context.*;
    return context.withValue(*Span, @ptrCast(@alignCast(span.ptr)));
}

pub const Tracer = struct {
    provider: *TracerProvider,
    instrumentation_scope: api.InstrumentationScope,

    pub fn tracer(this: *@This()) api.trace.Tracer {
        return .{ .ptr = this, .vtable = TRACER_VTABLE };
    }

    const TRACER_VTABLE = &api.trace.Tracer.VTable{
        .create_span = createSpan,
        .enabled = enabled,
    };

    pub fn createSpan(this_opaque: ?*anyopaque, name: []const u8, context: ?*const api.Context, options: api.trace.Tracer.CreateSpanOptions) api.trace.Span {
        const this: *@This() = @ptrCast(@alignCast(this_opaque));
        return this.createSpanFallible(name, context, options) catch return api.trace.Span.NULL;
    }

    fn createSpanFallible(this: @This(), name: []const u8, context_opt: ?*const api.Context, options: api.trace.Tracer.CreateSpanOptions) !api.trace.Span {
        const timestamp = options.start_timestamp orelse std.time.nanoTimestamp();

        // TODO: Sampler interfaces

        const node = this.provider.free_spans.popFirst() orelse
            try this.provider.allocateSpan();
        errdefer this.provider.free_spans.prepend(node);

        const span = &node.data;
        span.readWriteSpan().acquire();

        span.record.reset();
        span.record.name = name;
        span.record.resource = &this.provider.resource;
        span.record.scope = this.instrumentation_scope;
        span.record.start_timestamp = timestamp;
        span.record.kind = options.kind;

        const context = context_opt orelse api.Context.current();
        if (context.getValue(*Span)) |parent_span| {
            span.record.context.trace_id = parent_span.record.context.trace_id;
            span.record.parent_context = parent_span.record.context;
        }

        // TODO: IdGenerator interface
        if (!span.record.context.trace_id.isValid()) {
            std.crypto.random.bytes(&span.record.context.trace_id.bytes);
        }
        std.crypto.random.bytes(&span.record.context.span_id.bytes);

        try node.data.record.attributes.ensureTotalCapacity(this.provider.allocator, this.provider.limits.attribute_limits);
        try node.data.record.links.ensureTotalCapacity(this.provider.allocator, this.provider.limits.link_count_limit);
        try node.data.record.events.ensureTotalCapacity(this.provider.allocator, this.provider.limits.event_count_limit);

        for (options.attributes) |attr| {
            span.record.attributes.put(attr);
        }

        for (this.provider.span_processors) |processor| {
            processor.onStart(span.readWriteSpan(), context);
        }

        return span.span();
    }

    pub fn enabled(this_opaque: ?*anyopaque, options: api.trace.Tracer.EnabledOptions) bool {
        const this: *@This() = @ptrCast(@alignCast(this_opaque.?));
        _ = this;
        _ = options;
        return true;
    }
};

pub const Span = struct {
    provider: *TracerProvider,
    reference_count: u32,
    record: sdk.trace.SpanRecord,

    pub fn readableSpan(this: *@This()) sdk.trace.ReadableSpan {
        return .{ .ptr = this, .vtable = READABLE_SPAN_VTABLE };
    }

    pub const READABLE_SPAN_VTABLE = &sdk.trace.ReadableSpan.VTable{
        .acquire = read_span_acquire,
        .release = read_span_release,
        .get_data = read_span_getData,
    };

    pub fn read_span_acquire(this_opaque: ?*anyopaque) void {
        const this: *@This() = @ptrCast(@alignCast(this_opaque));
        this.reference_count += 1;
    }

    pub fn read_span_release(this_opaque: ?*anyopaque) void {
        const this: *@This() = @ptrCast(@alignCast(this_opaque));
        this.reference_count -= 1;
        if (this.reference_count == 0) {
            this.provider.free_spans.prepend(@fieldParentPtr("data", this));
        }
    }

    pub fn read_span_getData(this_opaque: ?*anyopaque) *const sdk.trace.SpanRecord {
        const this: *@This() = @ptrCast(@alignCast(this_opaque));
        return &this.record;
    }

    pub fn readWriteSpan(this: *@This()) sdk.trace.ReadWriteSpan {
        return .{ .ptr = this, .vtable = READ_WRITE_SPAN_VTABLE };
    }

    pub const READ_WRITE_SPAN_VTABLE = &sdk.trace.ReadWriteSpan.VTable{
        .acquire = read_span_acquire,
        .release = read_span_release,
        .writer = read_write_span_writer,
        .get_data = read_span_getData,
    };

    pub fn read_write_span_writer(this_opaque: ?*anyopaque) api.trace.Span {
        const this: *@This() = @ptrCast(@alignCast(this_opaque));
        return this.span();
    }

    pub fn span(this: *@This()) api.trace.Span {
        return .{ .ptr = this, .vtable = SPAN_VTABLE };
    }

    pub const SPAN_VTABLE = &api.trace.Span.VTable{
        .get_context = span_getContext,
        .is_recording = span_isRecording,
        .set_attribute = span_setAttribute,
        .add_event = span_addEvent,
        .add_link = span_addLink,
        .set_status = span_setStatus,
        .update_name = span_updateName,
        .end = span_end,
        .record_exception = span_recordException,
    };

    fn span_getContext(span_opaque: ?*anyopaque) api.trace.SpanContext {
        const this: *@This() = @ptrCast(@alignCast(span_opaque.?));
        return this.record.context;
    }

    fn span_isRecording(span_opaque: ?*anyopaque) bool {
        const this: *@This() = @ptrCast(@alignCast(span_opaque.?));
        return this.record.end_timestamp != null;
    }

    fn span_setAttribute(span_opaque: ?*anyopaque, attribute: api.Attribute) void {
        _ = span_opaque;
        _ = attribute;
    }

    fn span_addEvent(span_opaque: ?*anyopaque, options: api.trace.AddEventOptions) void {
        _ = span_opaque;
        _ = options;
    }

    fn span_addLink(span_opaque: ?*anyopaque, link: api.trace.Link) void {
        _ = span_opaque;
        _ = link;
    }

    fn span_setStatus(span_opaque: ?*anyopaque, status: api.trace.Status) void {
        _ = span_opaque;
        _ = status;
    }

    fn span_updateName(span_opaque: ?*anyopaque, new_name: []const u8) void {
        _ = span_opaque;
        _ = new_name;
    }

    fn span_end(span_opaque: ?*anyopaque, timestamp_opt: ?i128) void {
        const this: *@This() = @ptrCast(@alignCast(span_opaque.?));
        defer this.readableSpan().release();

        this.record.end_timestamp = timestamp_opt orelse std.time.nanoTimestamp();

        for (this.provider.span_processors) |processor| {
            processor.onEnd(this.readableSpan());
        }
    }

    fn span_recordException(span_opaque: ?*anyopaque, err: anyerror, stack_trace: ?std.builtin.StackTrace) void {
        _ = span_opaque;
        err catch {};
        _ = stack_trace;
    }
};

const api = @import("api");
const sdk = @import("../../sdk.zig");
const std = @import("std");
