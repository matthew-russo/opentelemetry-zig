allocator: std.mem.Allocator,
exporter: ?sdk.trace.SpanExporter,

pub const InitOptions = struct {};

pub fn create(allocator: std.mem.Allocator, exporter: sdk.trace.SpanExporter, options: InitOptions) !*@This() {
    const this = try allocator.create(@This());
    errdefer allocator.destroy(this);

    this.* = @This(){
        .allocator = allocator,
        .exporter = exporter,
    };
    _ = options;

    return this;
}

pub fn spanProcessor(this: *@This()) sdk.trace.SpanProcessor {
    return .{ .ptr = this, .vtable = SPAN_PROCESSOR_VTABLE };
}

pub const SPAN_PROCESSOR_VTABLE = &sdk.trace.SpanProcessor.VTable{
    .on_start = span_processor_onStart,
    .on_end = span_processor_onEnd,
    // .force_flush = stderr_exporter_forceFlush,
    .shutdown = stderr_exporter_shutdown,
};

fn span_processor_configure(this_opaque: ?*anyopaque, options: sdk.trace.SpanProcessor.ConfigureOptions) void {
    const this: *@This() = @ptrCast(@alignCast(this_opaque));
    this.exporter = options.exporter;
}

fn span_processor_onStart(this_opaque: ?*anyopaque, span: sdk.trace.ReadWriteSpan, parent_context: *const api.Context) void {
    const this: *@This() = @ptrCast(@alignCast(this_opaque));
    _ = this;
    _ = span;
    _ = parent_context;
}

fn span_processor_onEnd(this_opaque: ?*anyopaque, span: sdk.trace.ReadableSpan) void {
    const this: *@This() = @ptrCast(@alignCast(this_opaque));
    if (this.exporter) |exporter| {
        _ = exporter.@"export"(&.{span});
    }
}

// fn stderr_exporter_forceFlush(processor: sdk.trace.SpanProcessor) void {
//     _ = exporter;
//     listener.callback(listener, .success);
// }

fn stderr_exporter_shutdown(this_opaque: ?*anyopaque) void {
    const this: *@This() = @ptrCast(@alignCast(this_opaque));
    if (this.exporter) |exporter| {
        exporter.shutdown();
    }
    this.allocator.destroy(this);
}

const api = @import("api");
const sdk = @import("../../../sdk.zig");
const std = @import("std");
