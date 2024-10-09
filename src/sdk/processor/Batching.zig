allocator: std.mem.Allocator,
queue: std.ArrayListUnmanaged(*sdk.trace.DynamicTracerProvider.Span),
dropped_spans: u32 = 0,
max_batch_size: u32,

exporter: ?sdk.trace.SpanExporter,

pub const InitOptions = struct {
    max_queue_size: u32 = 2048,
    max_batch_size: u32 = 512,
};

pub fn create(allocator: std.mem.Allocator, options: InitOptions) !*@This() {
    std.debug.assert(options.max_batch_size < options.max_queue_size);

    var queue = try std.ArrayListUnmanaged(*sdk.trace.DynamicTracerProvider.Span).initCapacity(allocator, options.max_queue_size);
    errdefer queue.deinit(allocator);

    const this = try allocator.create(@This());
    errdefer allocator.destroy(this);
    this.* = @This(){
        .allocator = allocator,
        .queue = queue,
        .max_batch_size = options.max_batch_size,
        .exporter = null,
    };

    return this;
}

pub fn spanProcessor(this: *@This()) sdk.trace.SpanProcessor {
    return .{ .ptr = this, .vtable = SPAN_PROCESSOR_VTABLE };
}

pub const SPAN_PROCESSOR_VTABLE = &sdk.trace.SpanProcessor.VTable{
    .configure = span_processor_configure,
    .on_start = span_processor_onStart,
    .on_end = span_processor_onEnd,
    // .force_flush = stderr_exporter_forceFlush,
    .shutdown = span_processor_shutdown,
};

fn span_processor_configure(processor: sdk.trace.SpanProcessor, options: sdk.trace.SpanProcessor.ConfigureOptions) void {
    const this: *@This() = @ptrCast(@alignCast(processor.ptr));
    // this.dropped_spans += this.queue.items.len -| options.max_queue_size;

    // if (this.queue.items.len > options.max_queue_size) {
    //     this.queue.shrinkAndFree(this.allocator, options.max_queue_size);
    // } else {
    //     this.queue.ensureTotalCapacityPrecise(this.allocator, options.max_queue_size) catch |err| {
    //         std.log.err("failed to allocate BatchingSpanProcessor queue: {}", .{err});
    //     };
    // }

    // this.max_batch_size = this.max_batch_size;
    this.exporter = options.exporter;
}

fn span_processor_onStart(processor: sdk.trace.SpanProcessor, span: *sdk.trace.DynamicTracerProvider.Span, parent_context: *const api.Context) void {
    _ = processor;
    _ = span;
    _ = parent_context;
}

fn span_processor_onEnd(processor: sdk.trace.SpanProcessor, span: *sdk.trace.DynamicTracerProvider.Span) void {
    const this: *@This() = @ptrCast(@alignCast(processor.ptr));

    defer {
        if (this.exporter) |exporter| {
            if (this.queue.items.len >= this.max_batch_size) {
                const batch = this.queue.items[0..this.max_batch_size];
                switch (exporter.@"export"(batch)) {
                    .failure => {},
                    .success => {
                        for (batch) |s| {
                            s.release();
                        }
                        this.queue.replaceRangeAssumeCapacity(batch.len, this.queue.items.len - batch.len, this.queue.items[0..batch.len]);
                    },
                }
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

// fn stderr_exporter_forceFlush(processor: sdk.trace.SpanProcessor) void {
//     _ = exporter;
//     listener.callback(listener, .success);
// }

fn span_processor_shutdown(processor: sdk.trace.SpanProcessor) void {
    const this: *@This() = @ptrCast(@alignCast(processor.ptr));
    if (this.exporter) |exporter| {
        _ = exporter.@"export"(this.queue.items);
    }
    for (this.queue.items) |span| {
        span.release();
    }
    this.queue.deinit(this.allocator);
    this.allocator.destroy(this);
}

const api = @import("api");
const sdk = @import("../../sdk.zig");
const std = @import("std");
