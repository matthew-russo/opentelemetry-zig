const Exporter = @This();

ptr: ?*anyopaque,
vtable: *const VTable,

pub const Result = enum {
    success,
    failure,
};

pub const ForceFlushResultListener = struct {
    callback: *const fn (*ForceFlushResultListener, ForceFlushResult) void,
};

pub const ForceFlushResult = enum {
    success,
    failure,
    timeout,
};

pub const VTable = struct {
    @"export": *const fn (?*anyopaque, batch: []const sdk.trace.ReadableSpan) Result,
    force_flush: *const fn (?*anyopaque, listener: *ForceFlushResultListener) void,
    shutdown: *const fn (?*anyopaque) void,
};

pub fn @"export"(exporter: Exporter, batch: []const sdk.trace.ReadableSpan) Result {
    return exporter.vtable.@"export"(exporter.ptr, batch);
}

pub fn shutdown(exporter: Exporter) void {
    return exporter.vtable.shutdown(exporter.ptr);
}

const api = @import("api");
const sdk = @import("../../sdk.zig");
const std = @import("std");
