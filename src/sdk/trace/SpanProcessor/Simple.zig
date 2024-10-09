exporter: sdk.trace.SpanExporter,

pub fn spanProcessor(this: *@This()) sdk.trace.SpanProcessor {
    return .{ .ptr = this, .vtable = SPAN_PROCESSOR_VTABLE };
}

pub const SPAN_PROCESSOR_VTABLE = &sdk.trace.SpanProcessor.VTable{
    .on_start = span_processor_onStart,
    .on_end = span_processor_onEnd,
    // .force_flush = stderr_exporter_forceFlush,
    // .shutdown = stderr_exporter_shutdown,
};

fn span_processor_onStart(processor: sdk.trace.SpanProcessor, span: *sdk.trace.SpanRecord, parent_context: api.Context) void {
    _ = processor;
    _ = span;
    _ = parent_context;
}

fn span_processor_onEnd(processor: sdk.trace.SpanProcessor, span: *const sdk.trace.SpanRecord) void {
    const this: *@This() = @ptrCast(@alignCast(processor.ptr));
    _ = this.exporter.@"export"(span[0..1]);
}

// fn stderr_exporter_forceFlush(processor: sdk.trace.SpanProcessor) void {
//     _ = exporter;
//     listener.callback(listener, .success);
// }

// fn stderr_exporter_shutdown(processor: sdk.trace.SpanProcessor) void {
//     _ = exporter;
// }

const api = @import("api");
const sdk = @import("../../../sdk.zig");
const std = @import("std");
