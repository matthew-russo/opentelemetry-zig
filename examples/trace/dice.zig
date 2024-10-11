const otel = @import("opentelemetry-sdk");

pub const opentelemetry_options = otel.api.Options{
    .tracer_provider = getTracer,
    .context_extract_span = otel.trace.DynamicTracerProvider.contextExtractSpan,
    .context_with_span = otel.trace.DynamicTracerProvider.contextWithSpan,
};

var tracer_provider: *otel.trace.DynamicTracerProvider = undefined;
fn getTracer(comptime scope: otel.api.InstrumentationScope) otel.api.trace.Tracer {
    return tracer_provider.getTracer(scope);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const stderr_exporter = try otel.exporter.StdErr.create(gpa.allocator(), .{});
    const simple_span_processor = try otel.trace.SpanProcessor.Simple.create(gpa.allocator(), stderr_exporter.spanExporter(), .{});

    const otlp_exporter = try otel.exporter.OpenTelemetry.create(gpa.allocator(), .{});
    const batching_span_processor = try otel.trace.SpanProcessor.Batching.create(gpa.allocator(), otlp_exporter.spanExporter(), .{});

    tracer_provider = try otel.trace.DynamicTracerProvider.init(gpa.allocator(), .{
        .resource = .{
            .attributes = &.{
                .{ .standard = .{ .@"service.name" = "opentelemetry_examples_trace_dice" } },
            },
        },
        .span_processors = &.{
            simple_span_processor.spanProcessor(),
            batching_span_processor.spanProcessor(),
        },
    });
    defer tracer_provider.shutdown();

    const tracer = otel.api.trace.getTracer(.{ .name = "zig.opentelemetry.examples.trace.dice" });

    const args = try std.process.argsAlloc(gpa.allocator());
    defer std.process.argsFree(gpa.allocator(), args);

    var dice = std.ArrayList(u8).init(gpa.allocator());
    defer dice.deinit();
    if (args.len > 1) {
        for (args[1..]) |arg| {
            try dice.append(try std.fmt.parseInt(u8, arg, 10));
        }
    } else {
        try dice.append(20);
    }

    const dice_rolling_span = tracer.createSpan("rolling specified dice", null, .{});
    defer dice_rolling_span.end(null);
    const dice_rolling_context = otel.api.trace.contextWithSpan(otel.api.Context.current(), dice_rolling_span);

    const stdout = std.io.getStdOut();

    for (dice.items) |die| {
        const die_roll_span = tracer.createSpan("die roll", &dice_rolling_context, .{});
        defer die_roll_span.end(null);

        const die_roll = std.crypto.random.uintLessThan(u8, die);
        try stdout.writer().print("{}\n", .{die_roll + 1});
    }
}

const std = @import("std");
