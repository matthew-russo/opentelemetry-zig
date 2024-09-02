const std = @import("std");

const otel_api = @import("opentelemetry-api");

pub const InMemoryLoggerProvider = struct {
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
        const logger = self.allocator.create(InMemoryLogger) catch unreachable;
        logger.* = InMemoryLogger.init(
            self.allocator,
            name,
            version,
            schema_url,
            attributes,
        );
        return otel_api.logs.Logger.init(logger);
    }

    pub fn destroyLogger(self: *Self, logger: otel_api.logs.Logger) void {
        const in_mem_logger: *InMemoryLogger = @ptrCast(@alignCast(logger.ptr));
        in_mem_logger.deinit();
        self.allocator.destroy(in_mem_logger);
    }
};

pub const InMemoryLogger = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    name: []const u8,
    version: ?[]const u8,
    schema_url: ?[]const u8,
    attributes: []otel_api.attribute.Attribute,

    logs: std.ArrayList(otel_api.logs.LogRecord),

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
            .logs = std.ArrayList(otel_api.logs.LogRecord).init(allocator),
        };
    }

    fn deinit(self: *Self) void {
        self.logs.deinit();
    }

    pub fn emit(self: *Self, log_record: otel_api.logs.LogRecord) void {
        // TODO [matthew-russo 09-01-24] handle error
        // TODO [matthew-russo 09-01-24] merge the self params with log_record?
        self.logs.append(log_record) catch unreachable;
    }

    pub fn getEmittedLogs(self: *Self) []otel_api.logs.LogRecord {
        return self.logs.items[0..];
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
        .name = "InMemoryLog tests",
        .version = "0.1.0",
    },
    .attributes = std.StringHashMap(otel_api.logs.LogType).init(std.testing.allocator),
};

test "can construct InMemoryLoggerProvider" {
    _ = InMemoryLoggerProvider.init(std.testing.allocator);
}

test "can get Logger from InMemoryLoggerProvider" {
    var logger_provider = InMemoryLoggerProvider.init(std.testing.allocator);
    const logger = logger_provider.getLogger(
        "test_logger",
        "1.0.0",
        "schema_url",
        undefined,
    );
    defer logger_provider.destroyLogger(logger);
}

test "can use InMemoryLoggerProvider as a LoggerProvider" {
    const logger_provider_impl = try std.testing.allocator.create(InMemoryLoggerProvider);
    defer std.testing.allocator.destroy(logger_provider_impl);
    logger_provider_impl.* = InMemoryLoggerProvider.init(std.testing.allocator);
    _ = otel_api.logs.LoggerProvider.init(logger_provider_impl);
}

test "can get InMemoryLogger while using InMemoryLoggerProvider as a LoggerProvider" {
    const logger_provider_impl = try std.testing.allocator.create(InMemoryLoggerProvider);
    defer std.testing.allocator.destroy(logger_provider_impl);
    logger_provider_impl.* = InMemoryLoggerProvider.init(std.testing.allocator);
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
    const logger_provider_impl = try std.testing.allocator.create(InMemoryLoggerProvider);
    defer std.testing.allocator.destroy(logger_provider_impl);
    logger_provider_impl.* = InMemoryLoggerProvider.init(std.testing.allocator);
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

test "can retrieve emitted LogRecords" {
    const logger_provider_impl = try std.testing.allocator.create(InMemoryLoggerProvider);
    defer std.testing.allocator.destroy(logger_provider_impl);
    logger_provider_impl.* = InMemoryLoggerProvider.init(std.testing.allocator);
    var logger_provider = otel_api.logs.LoggerProvider.init(logger_provider_impl);
    var logger = logger_provider.getLogger(
        "test_logger",
        "1.0.0",
        "schema_url",
        undefined,
    );
    defer logger_provider.destroyLogger(logger);

    logger.emit(TEST_LOG);

    var logger_impl: *InMemoryLogger = @ptrCast(@alignCast(logger.ptr));
    const emitted_log = logger_impl.getEmittedLogs()[0];
    try std.testing.expect(std.meta.eql(emitted_log, TEST_LOG));
}
