const attribute = @import("../attribute.zig");
const tracer = @import("tracer.zig");

var global_trace_provider: ?TracerProvider = null;

pub fn setDefaultTracerProvider(tracer_provider: TracerProvider) void {
    global_trace_provider = tracer_provider;
}

pub fn unsetDefaultTracerProvider() void {
    global_trace_provider = null;
}

pub fn getDefaultTracerProvider() ?*TracerProvider {
    return &global_trace_provider;
}

pub const TracerProvider = struct {
    const Self = @This();

    ptr: *anyopaque,

    getTracerFn: *const fn (
        *anyopaque,
        []const u8,
        ?[]const u8,
        ?[]const u8,
        []attribute.Attribute,
    ) tracer.Tracer,

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
        if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

        const gen = struct {
            pub fn getTracerImpl(
                pointer: *anyopaque,
                name: []const u8,
                version: ?[]const u8,
                schema_url: ?[]const u8,
                attributes: []attribute.Attribute,
            ) tracer.Tracer {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.getTracer, .{ self, name, version, schema_url, attributes });
            }
        };

        return .{
            .ptr = ptr,
            .getTracerFn = gen.getTracerImpl,
        };
    }

    pub fn getTracer(
        self: *Self,
        name: []const u8,
        version: ?[]const u8,
        schema_url: ?[]const u8,
        attributes: []attribute.Attribute,
    ) tracer.Tracer {
        return self.getTracerFn(self.ptr, name, version, schema_url, attributes);
    }
};
