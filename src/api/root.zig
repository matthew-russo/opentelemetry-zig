const std = @import("std");

pub const attribute = @import("attribute.zig");
pub const baggage = @import("baggage.zig");
pub const context = @import("context.zig");
pub const global = @import("global.zig");
pub const logs = @import("logs.zig");
pub const metrics = @import("metrics.zig");
pub const resource = @import("resource.zig");
pub const span = @import("span.zig");
pub const traces = @import("traces.zig");

pub const Options = struct {
    logs_allocator: std.mem.Allocator,
    metrics_allocator: std.mem.Allocator,
    traces_allocator: std.mem.Allocator,
    rng: std.Random.DefaultPrng,
};

const root = @import("root");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var options: Options = if (@hasDecl(root, "otel_options")) root.otel_options else .{
    .logs_allocator = gpa.allocator(),
    .metrics_allocator = gpa.allocator(),
    .traces_allocator = gpa.allocator(),
    .rng = std.Random.DefaultPrng.init(0),
};

test {
    std.testing.refAllDeclsRecursive(attribute);
    std.testing.refAllDeclsRecursive(baggage);
    std.testing.refAllDeclsRecursive(context);
    // std.testing.refAllDeclsRecursive(global);
    std.testing.refAllDeclsRecursive(logs);
    std.testing.refAllDeclsRecursive(metrics);
    // std.testing.refAllDeclsRecursive(resource);
    // std.testing.refAllDeclsRecursive(span);
    // std.testing.refAllDeclsRecursive(traces);
}
