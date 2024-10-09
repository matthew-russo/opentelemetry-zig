const Processor = @This();

ptr: ?*anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    configure: *const fn (Processor, ConfigureOptions) void,
    on_start: *const fn (Processor, *sdk.trace.DynamicTracerProvider.Span, parent_context: *const api.Context) void,
    on_end: *const fn (Processor, *sdk.trace.DynamicTracerProvider.Span) void,
    shutdown: *const fn (Processor) void,
    // force_flush: *const fn (Processor) void,
};

pub const ConfigureOptions = struct {
    exporter: sdk.trace.SpanExporter,
};

pub fn configure(processor: Processor, options: ConfigureOptions) void {
    return processor.vtable.configure(processor, options);
}

pub fn onStart(processor: Processor, span: *sdk.trace.DynamicTracerProvider.Span, parent_context: *const api.Context) void {
    return processor.vtable.on_start(processor, span, parent_context);
}

pub fn onEnd(processor: Processor, span: *sdk.trace.DynamicTracerProvider.Span) void {
    return processor.vtable.on_end(processor, span);
}

pub fn shutdown(processor: Processor) void {
    return processor.vtable.shutdown(processor);
}

const api = @import("api");
const sdk = @import("../../sdk.zig");
