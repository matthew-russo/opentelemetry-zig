const otel = @import("opentelemetry-sdk");

pub const opentelemetry_options = otel.api.Options{
    .tracer_provider = otel.trace.DynamicTracerProvider,
};

pub const tracer = otel.api.trace.getTracer(.{ .name = "zig.opentelemetry.examples.trace.dice" });

fn initTelemetry(allocator: std.mem.Allocator) !void {
    var resource = try otel.Resource.detect(allocator, .{});
    errdefer resource.deinit(allocator);

    const simple_span_processor = try otel.processor.Simple.create(allocator, .{});
    errdefer simple_span_processor.spanProcessor().shutdown();

    const batch_processor = try otel.processor.Batching.create(allocator, .{});
    errdefer batch_processor.spanProcessor().shutdown();

    const stderr_exporter = try otel.exporter.StdErr.create(allocator, .{});
    errdefer stderr_exporter.spanExporter().shutdown();

    const otlp_exporter = try otel.exporter.OpenTelemetry.create(allocator, .{});
    errdefer otlp_exporter.spanExporter().shutdown();

    try otel.trace.DynamicTracerProvider.init(allocator, .{
        .resource = resource,
        .pipelines = &.{
            .{
                .processor = batch_processor.spanProcessor(),
                .exporter = otlp_exporter.spanExporter(),
            },
            .{
                .processor = simple_span_processor.spanProcessor(),
                .exporter = stderr_exporter.spanExporter(),
            },
        },
    });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try initTelemetry(gpa.allocator());
    defer otel.trace.DynamicTracerProvider.deinit();

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
