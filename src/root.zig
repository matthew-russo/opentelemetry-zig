const std = @import("std");

const api = @import("api/mod.zig");
const sdk = @import("sdk/mod.zig");

test {
    std.testing.refAllDecls(@This());
}
