pub const ContextValue = struct {};

pub const Context = struct {
    const Self = @This();

    ptr: *anyopaque,

    getValueFn: *const fn (*anyopaque, []const u8) ?ContextValue,
    withValueFn: *const fn (*anyopaque, []const u8) Self,

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
        if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

        const gen = struct {
            pub fn getValueImpl(pointer: *anyopaque, name: []const u8) ?ContextValue {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.getValue, .{ self, name });
            }

            pub fn withValueImpl(pointer: *anyopaque, name: []const u8, value: ContextValue) ptr_info.Pointer.child {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.withValue, .{ self, name, value });
            }
        };

        return .{
            .ptr = ptr,
            .getValueFn = gen.getValueImpl,
            .withValueFn = gen.withValueImpl,
        };
    }

    pub fn getValue(self: *Self, name: []const u8) ?ContextValue {
        return self.getValueFn(self.ptr, name);
    }

    pub fn withValue(self: *Self, name: []const u8, value: ContextValue) Self {
        return Self.init(self.withValue(self.ptr, name, value));
    }
};
