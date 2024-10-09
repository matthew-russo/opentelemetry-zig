pub const api = @import("api");

pub const exporter = @import("./sdk/exporter.zig");

pub const trace = @import("./sdk/trace.zig");

pub const AttributeLimits = struct {
    count_limit: usize = 128,
    value_length_limit: ?usize = null,
};

comptime {
    if (@import("builtin").is_test) {
        _ = trace;
    }
}
