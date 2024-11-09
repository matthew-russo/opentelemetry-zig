const std = @import("std");

const otel_api = @import("opentelemetry-api");
const otel_sdk = @import("opentelemetry-sdk");

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // write logs with LoggerProvider set at level debug
    const logger_provider = allocator.create(otel_sdk.traces.in_mem.InMemoryTracerProvider) catch unreachable;
    logger_provider.* = otel_sdk.traces.in_mem.InMemoryTracerProvider.init(allocator);
    otel_api.traces.setDefaultTracerProvider(otel_api.traces.TracerProvider.init(logger_provider));

    std.debug.print("[TracesExample] hello traces\n", .{});
}
