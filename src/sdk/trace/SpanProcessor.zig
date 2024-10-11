pub const Simple = @import("./SpanProcessor/Simple.zig");
pub const Batching = @import("./SpanProcessor/Batching.zig");

const Processor = @This();

ptr: ?*anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    on_start: *const fn (?*anyopaque, sdk.trace.ReadWriteSpan, parent_context: *const api.Context) void,
    on_end: *const fn (?*anyopaque, sdk.trace.ReadableSpan) void,
    shutdown: *const fn (?*anyopaque) void,
    // force_flush: *const fn (Processor) void,
};

pub fn onStart(processor: Processor, span: sdk.trace.ReadWriteSpan, parent_context: *const api.Context) void {
    return processor.vtable.on_start(processor.ptr, span, parent_context);
}

pub fn onEnd(processor: Processor, span: sdk.trace.ReadableSpan) void {
    return processor.vtable.on_end(processor.ptr, span);
}

pub fn shutdown(processor: Processor) void {
    return processor.vtable.shutdown(processor.ptr);
}

const api = @import("api");
const sdk = @import("../../sdk.zig");
