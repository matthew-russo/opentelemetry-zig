const std = @import("std");

const attribute = @import("./attribute.zig");
const context = @import("./context.zig");
const span = @import("./span.zig");

pub const TracerProvider = struct {
    const Self = @This();

    ptr: *anyopaque,

    getTracerFn: *const fn (
        *anyopaque,
        []const u8,
        ?[]const u8,
        ?[]const u8,
        std.StringHashMap(attribute.AttributeValue),
    ) Tracer,

    destroyTracerFn: *const fn (*anyopaque, Tracer) void,

    /// Construct a new TracerProvider using the concrete implementation
    /// of the provided type.
    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .pointer) @compileError("ptr must be a pointer");
        if (ptr_info.pointer.size != .one) @compileError("ptr must be a single item pointer");

        const gen = struct {
            pub fn getTracerImpl(
                pointer: *anyopaque,
                name: []const u8,
                version: ?[]const u8,
                schema_url: ?[]const u8,
                attributes: std.StringHashMap(attribute.AttributeValue),
            ) Tracer {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.pointer.child.getTracer, .{ self, name, version, schema_url, attributes });
            }

            pub fn destroyTracerImpl(
                pointer: *anyopaque,
                tracer: Tracer,
            ) void {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.pointer.child.destroyTracer, .{ self, tracer });
            }
        };

        return .{
            .ptr = ptr,
            .getTracerFn = gen.getTracerImpl,
            .destroyTracerFn = gen.destroyTracerImpl,
        };
    }

    /// Generate a new Tracer
    pub fn getTracer(
        self: *Self,
        name: []const u8,
        version: ?[]const u8,
        schema_url: ?[]const u8,
        attributes: std.StringHashMap(attribute.AttributeValue),
    ) Tracer {
        return self.getTracerFn(self.ptr, name, version, schema_url, attributes);
    }

    /// Destroy a Tracer created by this TracerProvider.
    ///
    /// #Safety
    /// The provided Tracer must have been acquired via a call to
    /// `getTracer` on the same TracerProvider
    pub fn destroyTracer(self: *Self, tracer: Tracer) void {
        return self.destroyTracerFn(self.ptr, tracer);
    }
};

pub const Tracer = struct {
    const Self = @This();

    ptr: *anyopaque,

    createSpanFn: *const fn (
        *anyopaque,
        []const u8,
        ?*context.Context,
        ?u64,
    ) span.Span,

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .pointer) @compileError("ptr must be a pointer");
        if (ptr_info.pointer.size != .one) @compileError("ptr must be a single item pointer");

        const gen = struct {
            pub fn createSpanImpl(
                pointer: *anyopaque,
                name: []const u8,
                ctx: ?*context.Context,
                start: ?u64,
            ) span.Span {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.pointer.child.createSpan, .{
                    self,
                    name,
                    ctx,
                    start,
                });
            }
        };

        return .{
            .ptr = ptr,
            .createSpanFn = gen.createSpanImpl,
        };
    }

    pub fn createSpan(
        self: *Self,
        name: []const u8,
        ctx: ?*context.Context,
        start: ?u64,
    ) span.Span {
        return self.createSpanFn(
            self.ptr,
            name,
            ctx,
            start,
        );
    }
};
