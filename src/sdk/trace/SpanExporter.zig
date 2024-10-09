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
    configure: *const fn (Exporter, ConfigureOptions) void,
    @"export": *const fn (Exporter, batch: []const sdk.trace.SpanRecord) Result,
    force_flush: *const fn (Exporter, listener: *ForceFlushResultListener) void,
    shutdown: *const fn (Exporter) void,
};

pub const ConfigureOptions = struct {
    resource: ?*const sdk.Resource,
};

pub fn configure(exporter: Exporter, options: ConfigureOptions) void {
    return exporter.vtable.configure(exporter, options);
}

pub fn @"export"(exporter: Exporter, batch: []const sdk.trace.SpanRecord) Result {
    return exporter.vtable.@"export"(exporter, batch);
}

pub fn shutdown(exporter: Exporter) void {
    return exporter.vtable.shutdown(exporter);
}

// stderr exporter
pub const STDERR = Exporter{
    .ptr = null,
    .vtable = &Exporter.VTable{
        .@"export" = stderr_exporter_export,
        .force_flush = stderr_exporter_forceFlush,
        .shutdown = stderr_exporter_shutdown,
    },
};

fn stderr_exporter_export(exporter: Exporter, batch: []const sdk.trace.SpanRecord) Result {
    _ = exporter;

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr();

    for (batch) |span_record| {
        stderr.writer().print("{}\n", .{std.json.fmt(span_record, .{ .emit_null_optional_fields = false })}) catch {};
    }

    return .success;
}

fn stderr_exporter_forceFlush(exporter: Exporter, listener: *ForceFlushResultListener) void {
    _ = exporter;
    listener.callback(listener, .success);
}

fn stderr_exporter_shutdown(exporter: Exporter) void {
    _ = exporter;
}

const api = @import("api");
const sdk = @import("../../sdk.zig");
const std = @import("std");
