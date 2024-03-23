const attribute = @import("../attribute.zig");
const logger = @import("logger.zig");

pub const LoggerProvider = struct {
    const Self = @This();

    ptr: *anyopaque,

    getLoggerFn: *const fn (*anyopaque, []const u8, ?[]const u8, ?[]const u8, []attribute.Attribute) logger.Logger;

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
        if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

        const gen = struct {
            pub fn getLoggerImpl(
                pointer: *anyopaque,
                name: []const u8,
                version: ?[]const u8,
                schema_url: ?[]const u8,
                attributes: []Attribute
            ) logger.Logger {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.getLogger, .{ self, name, version, schema_url, attributes });
            }
        };

        return .{
            .ptr = ptr,
            .getLoggerFn = gen.getLoggerFnImpl,
        };
    }

    pub fn getLogger(self: *Self, name: []const u8, version: ?[]const u8, schema_url: ?[]const u8, attributes: []Attribute) logger.Logger {
        return self.getLoggerFn(self.ptr, name, version, schema_url, attributes);
    }
};
