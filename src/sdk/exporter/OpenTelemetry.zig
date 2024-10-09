allocator: std.mem.Allocator,
running: bool,
thread: std.Thread,

resource: ?*const sdk.Resource = null,

traces_uri_string: []const u8,

traces_uri: std.Uri,

bodies_mutex: std.Thread.Mutex = .{},
message_bodies_to_send: std.DoublyLinkedList(Message) = .{},

const Message = struct {
    uri: std.Uri,
    payload: []const u8,
};

pub const InitOptions = struct {
    endpoint: []const u8 = "http://localhost:4318",
    traces_endpoint: ?[]const u8 = null,
};

pub fn create(allocator: std.mem.Allocator, options: InitOptions) !*@This() {
    const this = try allocator.create(@This());
    errdefer allocator.destroy(this);
    this.* = .{
        .allocator = allocator,
        .running = true,
        .thread = undefined,

        .traces_uri_string = undefined,
        .traces_uri = undefined,
    };

    this.traces_uri_string = if (options.traces_endpoint) |traces_endpoint|
        try allocator.dupe(u8, traces_endpoint)
    else
        try std.fs.path.join(allocator, &.{ options.endpoint, "v1/traces" });
    errdefer allocator.free(this.traces_uri_string);

    this.traces_uri = try std.Uri.parse(this.traces_uri_string);

    this.thread = try std.Thread.spawn(.{}, connectionThreadLoop, .{this});

    return this;
}

pub fn spanExporter(this: *@This()) sdk.trace.SpanExporter {
    return .{ .ptr = this, .vtable = SPAN_EXPORTER_VTABLE };
}

pub const SPAN_EXPORTER_VTABLE = &sdk.trace.SpanExporter.VTable{
    .configure = exporter_configure,
    .@"export" = exporter_export,
    .force_flush = exporter_forceFlush,
    .shutdown = exporter_shutdown,
};

fn exporter_configure(exporter: sdk.trace.SpanExporter, options: sdk.trace.SpanExporter.ConfigureOptions) void {
    const this: *@This() = @ptrCast(@alignCast(exporter.ptr));

    this.resource = options.resource;
}

fn exporter_export(exporter: sdk.trace.SpanExporter, batch: []const *sdk.trace.DynamicTracerProvider.Span) sdk.trace.SpanExporter.Result {
    const this: *@This() = @ptrCast(@alignCast(exporter.ptr));

    this.exportFallible(batch) catch {
        return .failure;
    };

    return .success;
}

fn exportFallible(this: *@This(), batch: []const *sdk.trace.DynamicTracerProvider.Span) !void {
    const node = try this.allocator.create(std.DoublyLinkedList(Message).Node);
    errdefer this.allocator.destroy(node);

    // TODO: sort spanrecords by instrumentation scope

    var records = std.ArrayListUnmanaged(*const sdk.trace.SpanRecord){};
    defer records.deinit(this.allocator);

    try records.resize(this.allocator, batch.len);

    for (records.items, batch) |*record, span| {
        record.* = &span.record;
    }

    const trace_payload: TracePayload = .{
        .resourceSpans = &.{.{
            .resource = this.resource,
            .scopeSpans = &.{
                .{
                    .scope = batch[0].record.scope,
                    .spans = records.items,
                },
            },
        }},
    };

    node.data = .{
        .uri = this.traces_uri,
        .payload = try std.json.stringifyAlloc(this.allocator, trace_payload, .{ .emit_null_optional_fields = false }),
    };
    errdefer this.allocator.free(node.data.payload);

    this.bodies_mutex.lock();
    defer this.bodies_mutex.unlock();
    this.message_bodies_to_send.append(node);
}

// comptime lessThanFn: fn (@TypeOf(context), lhs: T, rhs: T) bool,
// fn spanRecordLessThan(_: void, lhs: sdk.trace.SpanRecord, rhs: sdk.trace.SpanRecord) bool {
//     switch (lhs.resource)
// }

fn exporter_forceFlush(exporter: sdk.trace.SpanExporter, listener: *sdk.trace.SpanExporter.ForceFlushResultListener) void {
    _ = exporter;
    listener.callback(listener, .success);
}

fn exporter_shutdown(exporter: sdk.trace.SpanExporter) void {
    const this: *@This() = @ptrCast(@alignCast(exporter.ptr));
    this.running = false;
    this.thread.join();
    this.allocator.free(this.traces_uri_string);

    // for (this.resource_spans.values()) |scope_spans| {
    //     scope_spans.deinit(this.allocator);
    // }
    // this.resource_spans.deinit(this.allocator);

    this.allocator.destroy(this);
}

const TracePayload = struct {
    resourceSpans: []const ResourceSpan,

    const ResourceSpan = struct {
        resource: ?*const sdk.Resource,
        scopeSpans: []const ScopeSpans,
    };

    const ScopeSpans = struct {
        scope: api.InstrumentationScope,
        spans: []const *const sdk.trace.SpanRecord,
    };
};

fn connectionThreadLoop(this: *@This()) !void {
    var arena = std.heap.ArenaAllocator.init(this.allocator);
    defer arena.deinit();

    var client: std.http.Client = .{ .allocator = this.allocator };
    defer client.deinit();

    var response_storage = try std.ArrayListUnmanaged(u8).initCapacity(this.allocator, 8 * 1024);
    defer response_storage.deinit(this.allocator);

    try client.initDefaultProxies(arena.allocator());

    while (this.running or this.message_bodies_to_send.first != null) {
        response_storage.clearRetainingCapacity();

        const node = get_next_node: {
            this.bodies_mutex.lock();
            defer this.bodies_mutex.unlock();
            break :get_next_node this.message_bodies_to_send.pop() orelse continue;
        };
        defer {
            this.allocator.free(node.data.payload);
            this.allocator.destroy(node);
        }

        std.debug.print("{s}\n", .{node.data.payload});

        const response = try client.fetch(.{
            .location = .{ .uri = node.data.uri },
            .method = .POST,
            .headers = .{
                .content_type = .{ .override = "application/json" },
            },
            .payload = node.data.payload,
            .keep_alive = false,
            .response_storage = .{ .static = &response_storage },
        });
        if (response.status.class() != .success) {
            std.log.warn("{s}:{} {} {s}", .{ @src().file, @src().line, response.status, response_storage.items });
        }
    }
}

const api = @import("api");
const sdk = @import("../../sdk.zig");
const std = @import("std");
