const attribute = @import("../attribute.zig");
const meter = @import("meter.zig");

pub const MeterProvider = struct {
    const Self = @This();

    ptr: *anyopaque,

    getMeterFn: *const fn (*anyopaque, []const u8, ?[]const u8, ?[]const u8, []attribute.Attribute) meter.Meter,

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
        if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

        const gen = struct {
            pub fn getMeterImpl(pointer: *anyopaque, name: []const u8, version: ?[]const u8, schema_url: ?[]const u8, attributes: []attribute.Attribute) meter.Meter {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.getMeter, .{ self, name, version, schema_url, attributes });
            }
        };

        return .{
            .ptr = ptr,
            .getMeterFn = gen.getMeterImpl,
        };
    }

    pub fn getMeter(self: *Self, name: []const u8, version: ?[]const u8, schema_url: ?[]const u8, attributes: []attribute.Attribute) meter.Meter {
        return self.getMeterFn(self.ptr, name, version, schema_url, attributes);
    }
};
