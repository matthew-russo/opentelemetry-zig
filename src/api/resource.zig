pub const attribute = @import("attribute.zig");

pub const Resource = struct {
    const Self = @This();

    ptr: *anyopaque,

    emptyFn: *const fn () Self,
    createFn: *const fn ([]const attribute.Attribute, ?[]const u8) Self,
    mergeFn: *const fn (*anyopaque, Self) Self,
    retrieveFn: *const fn (*anyopaque) []const attribute.Attribute,

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
        if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

        const gen = struct {
            pub fn emptyImpl() Self {
                return @call(.always_inline, ptr_info.Pointer.child.empty, .{});
            }

            pub fn createImpl(attributes: []const attribute.Attribute, schema_url: ?[]const u8) Self {
                return @call(.always_inline, ptr_info.Pointer.child.create, .{ attributes, schema_url });
            }

            pub fn mergeImpl(pointer: *anyopaque, other: Self) Self {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.merge, .{ self, other });
            }

            pub fn retrieveImpl(pointer: *anyopaque) []const attribute.Attribute {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.retrieve, .{self});
            }
        };

        return .{
            .ptr = ptr,
            .emptyFn = gen.emptyImpl,
            .createFn = gen.createImpl,
            .mergeFn = gen.mergeImpl,
            .retrieveFn = gen.retrieveImpl,
        };
    }

    pub fn empty(self: *Self) Self {
        return self.emptyFn();
    }

    pub fn create(self: *Self, attributes: []attribute.Attribute, schema_url: ?[]const u8) Self {
        return self.createFn(attributes, schema_url);
    }

    pub fn merge(updating: *Self, old: Self) Self {
        return updating.mergeFn(updating.ptr, old);
    }

    pub fn retrieve(self: *Self) []const attribute.Attribute {
        return self.retrieveFn(self.ptr);
    }
};
