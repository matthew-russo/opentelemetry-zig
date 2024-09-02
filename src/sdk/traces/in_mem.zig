const std = @import("std");

const otel_api = @import("opentelemetry-api");

pub const InMemoryTracerProvider = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn getTracer(
        self: *Self,
        name: []const u8,
        version: ?[]const u8,
        schema_url: ?[]const u8,
        attributes: []otel_api.attribute.Attribute,
    ) otel_api.traces.Tracer {
        // TODO [matthew-russo] handle allocation errors
        const tracer = self.allocator.create(InMemoryTracer) catch unreachable;
        tracer.* = InMemoryTracer{
            .name = name,
            .version = version,
            .schema_url = schema_url,
            .attributes = attributes,
        };
        // TODO [matthew-russo] there is no mechanism to clean up
        // the allocated memory once we're done with the Tracer
        return otel_api.traces.Tracer.init(tracer);
    }

    pub fn destroyTracer(self: *Self, tracer: otel_api.traces.Tracer) void {
        const in_mem_tracer: *InMemoryTracer = @ptrCast(@alignCast(tracer.ptr));
        self.allocator.destroy(in_mem_tracer);
    }
};

pub const InMemoryTracer = struct {
    const Self = @This();

    name: []const u8,
    version: ?[]const u8,
    schema_url: ?[]const u8,
    attributes: []otel_api.attribute.Attribute,

    pub fn createSpan(
        self: *Self,
        name: []const u8,
        ctx: ?otel_api.context.Context,
        maybe_kind: ?otel_api.traces.Kind,
        attrs: []otel_api.attribute.Attribute,
        links: []otel_api.traces.Link,
        maybe_start: ?u64,
    ) otel_api.traces.Span {
        _ = self;
        _ = ctx;

        const kind = if (maybe_kind) |k| k else otel_api.traces.Kind.Internal;
        const start: u64 = if (maybe_start) |s| s else blk: {
            const nanosecs: u128 = @intCast(std.time.nanoTimestamp());
            const maxU64: u64 = std.math.maxInt(u64);
            const maxU64AsU128: u128 = @intCast(maxU64);
            std.debug.assert(nanosecs <= maxU64AsU128);
            break :blk @truncate(nanosecs);
        };

        return otel_api.traces.Span{
            .name = name,
            .ctx = std.debug.panic("todo: convert otel_api.context.Context to SpanContext", .{}),
            .parent = null,
            .kind = kind,
            .start = start,
            .end = 0,
            .attrs = attrs,
            .links = links,
            .events = undefined,
            .status = otel_api.traces.Status.Unset,
        };
    }
};

test "can construct InMemoryTracerProvider" {
    _ = InMemoryTracerProvider.init(std.testing.allocator);
}

test "can get Tracer from InMemoryTracerProvider" {
    var tracer_provider = InMemoryTracerProvider.init(std.testing.allocator);
    const tracer = tracer_provider.getTracer(
        "test_tracer",
        "1.0.0",
        "schema_url",
        undefined,
    );
    defer tracer_provider.destroyTracer(tracer);
}

test "can use InMemoryTracerProvider as a TracerProvider" {
    const trace_provider_impl = try std.testing.allocator.create(InMemoryTracerProvider);
    defer std.testing.allocator.destroy(trace_provider_impl);
    trace_provider_impl.* = InMemoryTracerProvider.init(std.testing.allocator);
    _ = otel_api.traces.TracerProvider.init(trace_provider_impl);
}

test "can get InMemoryTracer while using InMemoryTracerProvider as a TracerProvider" {
    const trace_provider_impl = try std.testing.allocator.create(InMemoryTracerProvider);
    defer std.testing.allocator.destroy(trace_provider_impl);
    trace_provider_impl.* = InMemoryTracerProvider.init(std.testing.allocator);
    var tracer_provider = otel_api.traces.TracerProvider.init(trace_provider_impl);
    const tracer = tracer_provider.getTracer(
        "test_tracer",
        "1.0.0",
        "schema_url",
        undefined,
    );
    defer tracer_provider.destroyTracer(tracer);
}
