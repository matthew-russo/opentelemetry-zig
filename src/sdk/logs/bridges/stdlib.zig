const std = @import("std");

pub fn stdlibOtelLogBridge(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = level;
    _ = scope;
    _ = format;
    _ = args;
    std.debug.panic("[TODO] impl stdlibOtelLogBridge", .{});
}
