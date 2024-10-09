allocator: std.mem.Allocator,
resource: ?*const sdk.Resource = null,

pub const InitOptions = struct {};

pub fn create(allocator: std.mem.Allocator, options: InitOptions) !*@This() {
    const this = try allocator.create(@This());
    errdefer allocator.destroy(this);
    this.* = .{
        .allocator = allocator,
    };
    _ = options;

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
    // const this: *@This() = @ptrCast(@alignCast(exporter.ptr));
    _ = exporter;

    const stderr = std.io.getStdErr();
    var buffered_writer = std.io.BufferedWriter(1024, std.fs.File.Writer){ .unbuffered_writer = stderr.writer() };
    defer buffered_writer.flush() catch {};
    const writer = buffered_writer.writer();

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();

    for (batch) |span| {
        const record = span.record;
        if (record.end_timestamp) |end_timestamp| {
            const duration = end_timestamp - record.start_timestamp;
            writer.print("trace({s}): {s} {}", .{ record.scope.name, record.name, std.fmt.fmtDuration(@intCast(duration)) }) catch {};
        } else {
            writer.print("trace({s}): {s} {} to {?}", .{ record.scope.name, record.name, record.start_timestamp, record.end_timestamp }) catch {};
        }

        if (record.attributes.kv.count() > 0) {
            writer.print(" {}", .{record.attributes}) catch {};
        }
        writer.writeByte('\n') catch {};
    }

    return .success;
}

fn exporter_forceFlush(exporter: sdk.trace.SpanExporter, listener: *sdk.trace.SpanExporter.ForceFlushResultListener) void {
    _ = exporter;
    listener.callback(listener, .success);
}

fn exporter_shutdown(exporter: sdk.trace.SpanExporter) void {
    const this: *@This() = @ptrCast(@alignCast(exporter.ptr));
    this.allocator.destroy(this);
}

const api = @import("api");
const sdk = @import("../../sdk.zig");
const std = @import("std");
