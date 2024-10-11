allocator: std.mem.Allocator,
queue: Queue,
dropped_spans: u32 = 0,
max_batch_size: u32,

exporter: sdk.trace.SpanExporter,

const Queue = std.ArrayListUnmanaged(sdk.trace.ReadableSpan);

pub const InitOptions = struct {
    max_queue_size: u32 = 2048,
    max_batch_size: u32 = 512,
};

pub fn create(allocator: std.mem.Allocator, exporter: sdk.trace.SpanExporter, options: InitOptions) !*@This() {
    std.debug.assert(options.max_batch_size < options.max_queue_size);

    var queue = try Queue.initCapacity(allocator, options.max_queue_size);
    errdefer queue.deinit(allocator);

    const this = try allocator.create(@This());
    errdefer allocator.destroy(this);
    this.* = @This(){
        .allocator = allocator,
        .queue = queue,
        .max_batch_size = options.max_batch_size,
        .exporter = exporter,
    };

    return this;
}

pub fn spanProcessor(this: *@This()) sdk.trace.SpanProcessor {
    return .{ .ptr = this, .vtable = SPAN_PROCESSOR_VTABLE };
}

pub const SPAN_PROCESSOR_VTABLE = &sdk.trace.SpanProcessor.VTable{
    .on_start = span_processor_onStart,
    .on_end = span_processor_onEnd,
    // .force_flush = stderr_exporter_forceFlush,
    .shutdown = span_processor_shutdown,
};

fn span_processor_onStart(this_opaque: ?*anyopaque, span: sdk.trace.ReadWriteSpan, parent_context: *const api.Context) void {
    _ = this_opaque;
    _ = span;
    _ = parent_context;
}

fn span_processor_onEnd(this_opaque: ?*anyopaque, span: sdk.trace.ReadableSpan) void {
    const this: *@This() = @ptrCast(@alignCast(this_opaque));

    defer {
        if (this.queue.items.len >= this.max_batch_size) {
            const batch = this.queue.items[0..this.max_batch_size];
            switch (this.exporter.@"export"(batch)) {
                .failure => {},
                .success => {
                    for (batch) |s| {
                        s.release();
                    }
                    this.queue.replaceRangeAssumeCapacity(0, this.queue.items.len - batch.len, this.queue.items[batch.len..]);
                },
            }
        }
    }
    if (this.queue.unusedCapacitySlice().len == 0) {
        this.dropped_spans += 1;
        return;
    }
    span.acquire();
    this.queue.appendAssumeCapacity(span);
}

fn span_processor_shutdown(this_opaque: ?*anyopaque) void {
    const this: *@This() = @ptrCast(@alignCast(this_opaque));
    _ = this.exporter.@"export"(this.queue.items);
    this.exporter.shutdown();
    for (this.queue.items) |span| {
        span.release();
    }
    this.queue.deinit(this.allocator);
    this.allocator.destroy(this);
}

const api = @import("api");
const sdk = @import("../../../sdk.zig");
const std = @import("std");
