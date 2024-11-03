const std = @import("std");

const otel_api = @import("opentelemetry-api");

pub const StdoutLoggerProvider = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn getLogger(
        self: *Self,
        name: []const u8,
        version: ?[]const u8,
        schema_url: ?[]const u8,
        attributes: []otel_api.attribute.Attribute,
    ) otel_api.logs.Logger {
        // TODO [matthew-russo] handle allocation errors
        const logger = self.allocator.create(StdoutLogger) catch unreachable;
        logger.* = StdoutLogger.init(
            self.allocator,
            name,
            version,
            schema_url,
            attributes,
        );
        return otel_api.logs.Logger.init(logger);
    }

    pub fn destroyLogger(self: *Self, logger: otel_api.logs.Logger) void {
        const in_mem_logger: *StdoutLogger = @ptrCast(@alignCast(logger.ptr));
        in_mem_logger.deinit();
        self.allocator.destroy(in_mem_logger);
    }
};

pub const StdoutLogger = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    name: []const u8,
    version: ?[]const u8,
    schema_url: ?[]const u8,
    attributes: []otel_api.attribute.Attribute,

    fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        version: ?[]const u8,
        schema_url: ?[]const u8,
        attributes: []otel_api.attribute.Attribute,
    ) Self {
        return Self{
            .allocator = allocator,
            .name = name,
            .version = version,
            .schema_url = schema_url,
            .attributes = attributes,
        };
    }

    fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn emit(self: *Self, log_record: otel_api.logs.LogRecord) void {
        // TODO:
        //   - self.severity_number
        //   - self.version
        //   - self.schema_url
        //   - trace_flags
        //   - resource
        //   - instrumentation_scope
        //   - attributes
        std.debug.print("[{s}] {s} trace_id={s}, span_id={s} [{d},{d}] {any}", .{
            log_record.severity_text,
            self.name,
            log_record.trace_id,
            log_record.span_id,
            log_record.timestamp,
            log_record.observed_timestamp,
            log_record.body,
        });
    }
};

const TEST_LOG = otel_api.logs.LogRecord{
    .timestamp = 0,
    .observed_timestamp = 1,
    .trace_id = "test_trace_id",
    .span_id = "test_span_id",
    .trace_flags = 2,
    .severity_text = "INFO",
    .severity_number = otel_api.logs.Severity.Info,
    .body = otel_api.logs.LogType{
        .string = "test log message body",
    },
    .resource = null, // ?otel_api.resource.Resource,
    .instrumentation_scope = otel_api.logs.InstrumentationScope{
        .name = "StdoutLog tests",
        .version = "0.1.0",
    },
    .attributes = std.StringHashMap(otel_api.logs.LogType).init(std.testing.allocator),
};

test "can construct StdoutLoggerProvider" {
    _ = StdoutLoggerProvider.init(std.testing.allocator);
}

test "can get Logger from StdoutLoggerProvider" {
    var logger_provider = StdoutLoggerProvider.init(std.testing.allocator);
    const logger = logger_provider.getLogger(
        "test_logger",
        "1.0.0",
        "schema_url",
        undefined,
    );
    defer logger_provider.destroyLogger(logger);
}

test "can use StdoutLoggerProvider as a LoggerProvider" {
    const logger_provider_impl = try std.testing.allocator.create(StdoutLoggerProvider);
    defer std.testing.allocator.destroy(logger_provider_impl);
    logger_provider_impl.* = StdoutLoggerProvider.init(std.testing.allocator);
    _ = otel_api.logs.LoggerProvider.init(logger_provider_impl);
}

test "can get StdoutLogger while using StdoutLoggerProvider as a LoggerProvider" {
    const logger_provider_impl = try std.testing.allocator.create(StdoutLoggerProvider);
    defer std.testing.allocator.destroy(logger_provider_impl);
    logger_provider_impl.* = StdoutLoggerProvider.init(std.testing.allocator);
    var logger_provider = otel_api.logs.LoggerProvider.init(logger_provider_impl);
    const logger = logger_provider.getLogger(
        "test_logger",
        "1.0.0",
        "schema_url",
        undefined,
    );
    defer logger_provider.destroyLogger(logger);
}

test "can emit LogRecords" {
    const logger_provider_impl = try std.testing.allocator.create(StdoutLoggerProvider);
    defer std.testing.allocator.destroy(logger_provider_impl);
    logger_provider_impl.* = StdoutLoggerProvider.init(std.testing.allocator);
    var logger_provider = otel_api.logs.LoggerProvider.init(logger_provider_impl);
    var logger = logger_provider.getLogger(
        "test_logger",
        "1.0.0",
        "schema_url",
        undefined,
    );
    defer logger_provider.destroyLogger(logger);
    logger.emit(TEST_LOG);
}
