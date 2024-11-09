const std = @import("std");

pub const attribute = @import("attribute.zig");
pub const baggage = @import("baggage.zig");
pub const context = @import("context.zig");
pub const logs = @import("logs.zig");
pub const metrics = @import("metrics.zig");
pub const resource = @import("resource.zig");
pub const span = @import("span.zig");
pub const traces = @import("traces.zig");

pub const Options = struct {
    logs_allocator: std.mem.Allocator,
    metrics_allocator: std.mem.Allocator,
    traces_allocator: std.mem.Allocator,
};

const root = @import("root");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const options: Options = if (@hasDecl(root, "otel_options")) root.otel_options else .{
    .logs_allocator = gpa.allocator(),
    .metrics_allocator = gpa.allocator(),
    .traces_allocator = gpa.allocator(),
};

test {
    std.testing.refAllDeclsRecursive(@This());
}
