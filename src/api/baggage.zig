const std = @import("std");

const BaggageMap = std.hash_map.StringHashMap([]const u8);

pub const BaggageValue = struct {};

pub const Baggage = struct {
    const Self = @This();

    /// The iterator type returned by getAllValues()
    pub const Iterator = BaggageMap.Iterator;

    allocator: std.mem.Allocator,
    kvps: BaggageMap,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .kvps = BaggageMap.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.kvps.deinit();
    }

    pub fn getValue(self: *Self, name: []const u8) ?[]const u8 {
        return self.kvps.get(name);
    }

    pub fn getAllValues(self: *Self) Iterator {
        return self.kvps.iterator();
    }

    pub fn setValue(self: *Self, name: []const u8, value: []const u8) anyerror!Self {
        var cloned_map = try self.kvps.clone();
        try cloned_map.put(name, value);
        return Self{
            .allocator = self.allocator,
            .kvps = cloned_map,
        };
    }

    pub fn removeValue(self: *Self, name: []const u8) anyerror!Self {
        var cloned_map = try self.kvps.clone();
        _ = cloned_map.remove(name);
        return Self{
            .allocator = self.allocator,
            .kvps = cloned_map,
        };
    }
};
