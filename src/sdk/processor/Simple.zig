allocator: std.mem.Allocator,
exporter: ?sdk.trace.SpanExporter,

pub const InitOptions = struct {};

pub fn create(allocator: std.mem.Allocator, options: InitOptions) !*@This() {
    const this = try allocator.create(@This());
    errdefer allocator.destroy(this);

    this.* = @This(){
        .allocator = allocator,
        .exporter = null,
    };
    _ = options;

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
    .shutdown = stderr_exporter_shutdown,
};

fn span_processor_configure(processor: sdk.trace.SpanProcessor, options: sdk.trace.SpanProcessor.ConfigureOptions) void {
    const this: *@This() = @ptrCast(@alignCast(processor.ptr));
    this.exporter = options.exporter;
}

fn span_processor_onStart(processor: sdk.trace.SpanProcessor, span: *sdk.trace.DynamicTracerProvider.Span, parent_context: *const api.Context) void {
    _ = processor;
    _ = span;
    _ = parent_context;
}

fn span_processor_onEnd(processor: sdk.trace.SpanProcessor, span: *sdk.trace.DynamicTracerProvider.Span) void {
    const this: *@This() = @ptrCast(@alignCast(processor.ptr));
    if (this.exporter) |exporter| {
        _ = exporter.@"export"(&.{span});
    }
}

// fn stderr_exporter_forceFlush(processor: sdk.trace.SpanProcessor) void {
//     _ = exporter;
//     listener.callback(listener, .success);
// }

fn stderr_exporter_shutdown(processor: sdk.trace.SpanProcessor) void {
    const this: *@This() = @ptrCast(@alignCast(processor.ptr));
    this.allocator.destroy(this);
}

const api = @import("api");
const sdk = @import("../../sdk.zig");
const std = @import("std");
