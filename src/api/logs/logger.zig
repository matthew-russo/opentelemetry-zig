const record = @import("record.zig");

pub const Logger = struct {
    const Self = @This();

    ptr: *anyopaque,

    emitFn: *const fn (*anyopaque, record.LogRecord);

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
        if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

        const gen = struct {
            pub fn emitFnImpl(pointer: *anyopaque, log: record.LogRecord) void {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.emit, .{ self, log })
            }
        };

        return .{
            .ptr = ptr,
            .emitFn = gen.emitFnImpl,
        };
    }

    pub fn emit(self: *Self, log: record.LogRecord) void {
        return self.emitFn(self.ptr, log);
    }
};
