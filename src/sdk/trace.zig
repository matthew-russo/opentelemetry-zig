pub const SpanProcessor = @import("./trace/SpanProcessor.zig");
pub const SpanExporter = @import("./trace/SpanExporter.zig");

pub const SpanLimits = struct {
    attribute_limits: sdk.AttributeLimits = .{},
    event_count_limit: usize = 128,
    link_count_limit: usize = 128,
    attribute_per_event_count_limit: usize = 128,
    attribute_per_link_count_limit: usize = 128,
};

pub const SpanRecord = struct {
    name: []const u8,
    scope: api.InstrumentationScope,
    context: api.trace.SpanContext,
    parent_span_id: ?api.trace.SpanId,
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
        this.parent_span_id = api.trace.SpanId.INVALID;
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

        if (this.parent_span_id) |parent_span_id| {
            try jw.objectField("parentSpanId");
            try jw.write(parent_span_id);
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

pub const DynamicTracerProvider = struct {
    allocator: std.mem.Allocator,
    resource: sdk.Resource,
    limits: sdk.trace.SpanLimits = .{},
    max_spans: usize,
    pipelines: std.ArrayListUnmanaged(Pipeline),
    free_spans: std.SinglyLinkedList(Span),

    var global_dynamic_tracer_provider: ?DynamicTracerProvider = null;

    pub const Pipeline = struct {
        processor: SpanProcessor,
        exporter: SpanExporter,
    };

    pub const InitOptions = struct {
        resource: sdk.Resource,
        limits: SpanLimits = .{},
        pipelines: []const Pipeline,
        max_spans: usize = 1024,
    };

    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !void {
        std.debug.assert(global_dynamic_tracer_provider == null);

        var pipelines = std.ArrayListUnmanaged(Pipeline){};
        errdefer pipelines.deinit(allocator);
        try pipelines.appendSlice(allocator, options.pipelines);

        global_dynamic_tracer_provider = DynamicTracerProvider{
            .allocator = allocator,
            .resource = options.resource,
            .limits = options.limits,
            .max_spans = options.max_spans,
            .pipelines = pipelines,
            .free_spans = .{},
        };

        for (0..options.max_spans) |_| {
            const node = try allocator.create(std.SinglyLinkedList(Span).Node);
            node.data = .{
                .provider = &global_dynamic_tracer_provider.?,
                .reference_count = 0,
                .record = .{
                    .name = "",
                    .scope = .{ .name = "" },
                    .context = .{
                        .trace_id = api.trace.TraceId.INVALID,
                        .span_id = api.trace.SpanId.INVALID,
                        .flags = api.trace.Flags.NONE,
                        .state = .{
                            .values = &.{},
                        },
                        .is_remote = false,
                    },
                    .parent_span_id = api.trace.SpanId.INVALID,
                    .kind = .unspecified,
                    .start_timestamp = undefined,
                    .end_timestamp = null,
                    .attributes = .{},
                    .links = .{},
                    .dropped_links_count = 0,
                    .events = .{},
                    .dropped_events_count = 0,
                    .status = .unset,
                },
            };

            try node.data.record.attributes.ensureTotalCapacity(allocator, options.limits.attribute_limits.count_limit, 4096, 4096);
            try node.data.record.links.ensureTotalCapacity(allocator, options.limits.link_count_limit);
            try node.data.record.events.ensureTotalCapacity(allocator, options.limits.event_count_limit);
            global_dynamic_tracer_provider.?.free_spans.prepend(node);
        }

        for (pipelines.items) |pipeline| {
            pipeline.processor.configure(.{
                .exporter = pipeline.exporter,
            });
            pipeline.exporter.configure(.{
                .resource = &global_dynamic_tracer_provider.?.resource,
            });
        }
    }

    pub fn deinit() void {
        const tracer_provider = &(global_dynamic_tracer_provider orelse return);

        for (tracer_provider.pipelines.items) |pipeline| {
            pipeline.processor.shutdown();
            pipeline.exporter.shutdown();
        }
        tracer_provider.pipelines.deinit(tracer_provider.allocator);

        tracer_provider.resource.deinit(tracer_provider.allocator);
        while (tracer_provider.free_spans.popFirst()) |node| {
            node.data.record.deinit(tracer_provider.allocator);
            tracer_provider.allocator.destroy(node);
        }

        global_dynamic_tracer_provider = null;
    }

    pub fn getTracer(comptime instrumentation_scope: api.InstrumentationScope) Tracer {
        return .{
            .instrumentation_scope = instrumentation_scope,
        };
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
        instrumentation_scope: api.InstrumentationScope,

        pub fn createSpan(this: @This(), name: []const u8, context: ?*const api.Context, options: api.trace.CreateSpanOptions) api.trace.Span {
            return this.createSpanFallible(name, context, options) catch return api.trace.Span.null;
        }

        fn createSpanFallible(this: @This(), name: []const u8, context_opt: ?*const api.Context, options: api.trace.CreateSpanOptions) !api.trace.Span {
            const tracer_provider = &(global_dynamic_tracer_provider orelse return api.trace.Span.null);

            const timestamp = options.start_timestamp orelse std.time.nanoTimestamp();

            // TODO: Sampler interfaces

            const node = tracer_provider.free_spans.popFirst() orelse return api.trace.Span.null;
            errdefer tracer_provider.free_spans.prepend(node);

            const span = &node.data;
            span.acquire();
            span.record.reset();
            span.record.name = name;
            span.record.scope = this.instrumentation_scope;
            span.record.start_timestamp = timestamp;
            span.record.kind = options.kind;

            const context = context_opt orelse api.Context.current();
            if (context.getValue(*Span)) |parent_span| {
                span.record.context.trace_id = parent_span.record.context.trace_id;
                span.record.parent_span_id = parent_span.record.context.span_id;
            }

            // TODO: IdGenerator interface
            if (!span.record.context.trace_id.isValid()) {
                std.crypto.random.bytes(&span.record.context.trace_id.bytes);
            }
            std.crypto.random.bytes(&span.record.context.span_id.bytes);

            try span.record.attributes.ensureTotalCapacity(tracer_provider.allocator, tracer_provider.limits.attribute_limits.count_limit, 4096, 4096);
            try span.record.links.ensureTotalCapacity(tracer_provider.allocator, tracer_provider.limits.link_count_limit);
            try span.record.events.ensureTotalCapacity(tracer_provider.allocator, tracer_provider.limits.event_count_limit);

            for (options.attributes) |attr| {
                span.record.attributes.put(attr);
            }

            for (tracer_provider.pipelines.items) |pipeline| {
                pipeline.processor.onStart(span, context);
            }

            return span.span();
        }

        pub fn enabled(this_opaque: api.trace.Tracer, options: api.trace.Tracer.EnabledOptions) bool {
            const this: *@This() = @ptrCast(@alignCast(this_opaque.ptr.?));
            _ = this;
            _ = options;
            return true;
        }
    };

    pub const Span = struct {
        provider: *DynamicTracerProvider,
        reference_count: u32,
        record: sdk.trace.SpanRecord,

        pub fn acquire(this: *@This()) void {
            this.reference_count += 1;
        }

        pub fn release(this: *@This()) void {
            this.reference_count -= 1;
            if (this.reference_count == 0) {
                this.provider.free_spans.prepend(@fieldParentPtr("data", this));
            }
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

        fn span_getContext(span_opaque: api.trace.Span) api.trace.SpanContext {
            const this: *@This() = @ptrCast(@alignCast(span_opaque.ptr.?));
            return this.record.context;
        }

        fn span_isRecording(span_opaque: api.trace.Span) bool {
            const this: *@This() = @ptrCast(@alignCast(span_opaque.ptr.?));
            return this.record.end_timestamp != null;
        }

        fn span_setAttribute(span_opaque: api.trace.Span, attribute: api.Attribute) void {
            _ = span_opaque;
            _ = attribute;
        }

        fn span_addEvent(span_opaque: api.trace.Span, options: api.trace.AddEventOptions) void {
            _ = span_opaque;
            _ = options;
        }

        fn span_addLink(span_opaque: api.trace.Span, link: api.trace.Link) void {
            _ = span_opaque;
            _ = link;
        }

        fn span_setStatus(span_opaque: api.trace.Span, status: api.trace.Status) void {
            _ = span_opaque;
            _ = status;
        }

        fn span_updateName(span_opaque: api.trace.Span, new_name: []const u8) void {
            _ = span_opaque;
            _ = new_name;
        }

        fn span_end(span_opaque: api.trace.Span, timestamp_opt: ?i128) void {
            const this: *@This() = @ptrCast(@alignCast(span_opaque.ptr.?));
            defer this.release();

            this.record.end_timestamp = timestamp_opt orelse std.time.nanoTimestamp();

            for (this.provider.pipelines.items) |pipeline| {
                pipeline.processor.onEnd(this);
            }
        }

        fn span_recordException(span_opaque: api.trace.Span, err: anyerror, stack_trace: ?std.builtin.StackTrace) void {
            _ = span_opaque;
            err catch {};
            _ = stack_trace;
        }
    };
};

const api = @import("api");
const sdk = @import("../sdk.zig");
const std = @import("std");
