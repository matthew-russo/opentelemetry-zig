pub const api = @import("api");

pub const exporter = @import("./sdk/exporter.zig");

pub const trace = @import("./sdk/trace.zig");

pub const AttributeSet = @import("./sdk/AttributeSet.zig");
pub const Resource = @import("./sdk/Resource.zig");

comptime {
    if (@import("builtin").is_test) {
        _ = trace;
    }
}
