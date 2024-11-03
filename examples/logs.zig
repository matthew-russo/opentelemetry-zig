const std = @import("std");
const otel_api = @import("opentelemetry-api");
const otel_sdk = @import("opentelemetry-sdk");

pub const std_options: std.Options = .{
    // Set the log level to info
    .log_level = .debug,

    // Define logFn to override the std implementation
    .logFn = otel_sdk.logs.bridges.stdlib.stdlibOtelLogBridge,
};

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // write logs with no LoggerProvider set
    stdlibLogs();

    // write logs with LoggerProvider set at level debug
    const logger_provider = allocator.create(otel_sdk.logs.appenders.debug_stdout.StdoutLoggerProvider) catch unreachable;
    logger_provider.* = otel_sdk.logs.appenders.debug_stdout.StdoutLoggerProvider.init(allocator);
    otel_api.logs.setDefaultLoggerProvider(otel_api.logs.LoggerProvider.init(logger_provider));

    stdlibLogs();
}

pub fn stdlibLogs() void {
    std.log.debug("[LogsExample] hello debug logs\n", .{});
    std.log.info("[LogsExample] hello info logs\n", .{});
    std.log.warn("[LogsExample] hello warn logs\n", .{});
    std.log.err("[LogsExample] hello error logs\n", .{});
}
