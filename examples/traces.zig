const std = @import("std");

const otel_api = @import("opentelemetry-api");
const otel_sdk = @import("opentelemetry-sdk");

const tracer_name = "traces-example";

fn foo() void {
    bar();
}

fn bar() void {
    baz();
}

fn baz() void {}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const tracer_provider = allocator.create(otel_sdk.traces.in_mem.InMemoryTracerProvider) catch unreachable;
    tracer_provider.* = otel_sdk.traces.in_mem.InMemoryTracerProvider.init(allocator);
    otel_api.global.setTracerProvider(otel_api.traces.TracerProvider.init(tracer_provider));

    foo();

    std.debug.print("[TracesExample] hello traces\n", .{});
}
