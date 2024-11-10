const std = @import("std");
const oasis = @import("oasis");

const otel_api = @import("opentelemetry-api");

pub fn stdlibOtelLogBridge(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    if (otel_api.global.getLoggerProvider().*) |*lp| {
        // TODO [matthew-russo] store a global map of loggers and have some
        // lifecycle to clean them up
        var logger = lp.getLogger(
            @tagName(scope),
            "0.1.0",
            undefined, // schema_url
            undefined, // attributes
        );
        defer lp.destroyLogger(logger);

        var severity_text = otel_api.logs.SEVERITY_TRACE_NAME;
        var severity_number = otel_api.logs.Severity.Trace;
        switch (level) {
            .debug => {
                severity_text = otel_api.logs.SEVERITY_DEBUG_NAME;
                severity_number = otel_api.logs.Severity.Debug;
            },
            .info => {
                severity_text = otel_api.logs.SEVERITY_INFO_NAME;
                severity_number = otel_api.logs.Severity.Info;
            },
            .warn => {
                severity_text = otel_api.logs.SEVERITY_WARN_NAME;
                severity_number = otel_api.logs.Severity.Warn;
            },
            .err => {
                severity_text = otel_api.logs.SEVERITY_ERROR_NAME;
                severity_number = otel_api.logs.Severity.Error;
            },
        }

        const msg = std.fmt.allocPrint(otel_api.options.logs_allocator, format, args) catch unreachable;
        defer otel_api.options.logs_allocator.free(msg);

        const now = oasis.time.nanosSinceEpoch();
        const log_record = otel_api.logs.LogRecord{
            .timestamp = now,
            .observed_timestamp = now,
            .trace_id = "placeholder_trace_id",
            .span_id = "placeholder_span_id",
            .trace_flags = undefined,
            .severity_text = severity_text,
            .severity_number = severity_number,
            .body = otel_api.logs.LogType{
                .string = msg,
            },
            .resource = null,
            .instrumentation_scope = undefined,
            //     otel_api.logs.InstrumentationScope{
            //     .name = "StdoutLog tests",
            //     .version = "0.1.0",
            // },
            .attributes = undefined,
        };

        logger.emit(log_record);
    }
}
