attributes: sdk.AttributeSet,

pub const DetectOptions = struct {
    /// If not provided, will be automatically detected from first command line argument.
    /// If that fails, `service.name` will be set to "unknown_service".
    @"service.name": ?[]const u8 = null,
};

pub const TELEMETRY_SDK = .{
    .@"telemetry.sdk.language" = "zig",
    .@"telemetry.sdk.name" = "opentelemetry-zig",
    .@"telemetry.sdk.version" = "0.0.0",
};

pub fn detect(allocator: std.mem.Allocator, options: DetectOptions) !@This() {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var arg_iter = std.process.args();
    const arg0 = arg_iter.next();

    const attribute_list = api.Attribute.listFromStruct(.{
        .@"service.name" = options.@"service.name" orelse if (arg0 == null or std.fs.path.basename(arg0.?).len == 0)
            "unknown_service"
        else
            try std.fmt.allocPrint(arena.allocator(), "unknown_service:{s}", .{std.fs.path.basename(arg0.?)}),

        .@"telemetry.sdk.language" = TELEMETRY_SDK.@"telemetry.sdk.language",
        .@"telemetry.sdk.name" = TELEMETRY_SDK.@"telemetry.sdk.name",
        .@"telemetry.sdk.version" = TELEMETRY_SDK.@"telemetry.sdk.version",
    });

    return .{ .attributes = try sdk.AttributeSet.fromList(allocator, &attribute_list) };
}

pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
    this.attributes.deinit(allocator);
}

const api = @import("api");
const sdk = @import("../sdk.zig");
const builtin = @import("builtin");
const std = @import("std");
