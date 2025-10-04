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
        attributes: std.StringHashMap(otel_api.attribute.AttributeValue),
    ) otel_api.traces.Tracer {
        // TODO [matthew-russo] handle allocation errors
        const tracer = self.allocator.create(InMemoryTracer) catch unreachable;
        tracer.* = InMemoryTracer{
            .allocator = self.allocator,

            .name = name,
            .version = version,
            .schema_url = schema_url,
            .attributes = attributes,
        };
        return otel_api.traces.Tracer.init(tracer);
    }

    pub fn destroyTracer(self: *Self, tracer: otel_api.traces.Tracer) void {
        const in_mem_tracer: *InMemoryTracer = @ptrCast(@alignCast(tracer.ptr));
        self.allocator.destroy(in_mem_tracer);
    }
};

pub const InMemoryTracer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    name: []const u8,
    version: ?[]const u8,
    schema_url: ?[]const u8,
    attributes: std.StringHashMap(otel_api.attribute.AttributeValue),

    pub fn createSpan(
        self: *Self,
        name: []const u8,
        ctx: ?*otel_api.context.Context,
        maybe_start: ?u64,
    ) otel_api.span.Span {
        const start: u64 = if (maybe_start) |s| s else blk: {
            const nanosecs: u128 = @intCast(std.time.nanoTimestamp());
            const maxU64: u64 = std.math.maxInt(u64);
            const maxU64AsU128: u128 = @intCast(maxU64);
            std.debug.assert(nanosecs <= maxU64AsU128);
            break :blk @truncate(nanosecs);
        };

        var span_ctx: ?otel_api.span.SpanContext = null;
        var parent: ?otel_api.span.ParentSpan = null;
        if (ctx) |parent_ctx| {
            if (parent_ctx.span) |*parent_span| {
                span_ctx = otel_api.span.SpanContext.init(
                    parent_span.*.ctx.trace_id,
                    otel_api.span.SpanId.random(),
                    otel_api.span.Flags.init(),
                    otel_api.span.TraceState.init(self.allocator),
                    false, // is_remote
                );

                parent = otel_api.span.ParentSpan{
                    .span = parent_span,
                };
            }
        }

        // if our span context is still null (no parent),
        // intiialize it
        if (span_ctx) |_| {} else {
            span_ctx = otel_api.span.SpanContext.init(
                otel_api.span.TraceId.random(),
                otel_api.span.SpanId.random(),
                otel_api.span.Flags.init(),
                otel_api.span.TraceState.init(self.allocator),
                false, // is_remote
            );
        }

        return otel_api.span.Span.init(
            self.allocator,
            name,
            span_ctx.?,
            parent,
            start,
        );
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

test "can create span with InMemoryTracer" {
    const trace_provider_impl = try std.testing.allocator.create(InMemoryTracerProvider);
    defer std.testing.allocator.destroy(trace_provider_impl);
    trace_provider_impl.* = InMemoryTracerProvider.init(std.testing.allocator);
    var tracer_provider = otel_api.traces.TracerProvider.init(trace_provider_impl);
    var tracer = tracer_provider.getTracer(
        "test_tracer",
        "1.0.0",
        "schema_url",
        undefined,
    );
    defer tracer_provider.destroyTracer(tracer);

    _ = tracer.createSpan(
        "test_span",
        null, // ctx,
        null, // maybe_start
    );
}
