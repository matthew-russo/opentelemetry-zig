const std = @import("std");

pub const ContextValue = struct {};

pub const Context = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    values: std.StringHashMap(ContextValue),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .values = std.StringHashMap(ContextValue).init(allocator),
        };
    }

    pub fn clone(self: *Self) Self {
        return Self{
            .allocator = self.allocator,
            .values = self.values.clone(),
        };
    }

    pub fn getValue(self: *Self, name: []const u8) ?ContextValue {
        return self.values.get(name);
    }

    pub fn withValue(self: *Self, name: []const u8, value: ContextValue) Self {
        var new_context = self.clone();
        new_context.setValue(name, value);
        return new_context;
    }

    // internal mutator, not publicly accessible. users will generate updated
    // contexts via `withValue` which clones the current Context
    fn setValue(self: *Self, name: []const u8, value: ContextValue) void {
        // ignore OOMs
        self.values.put(name, value) catch unreachable;
    }
};
