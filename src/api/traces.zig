const std = @import("std");

const attribute = @import("./attribute.zig");
const context = @import("./context.zig");
const span = @import("./span.zig");

// A global TracerProvider, interacted with through the apis:
// - setDefaultTraceProvider
// - unsetDefaultTraceProvider
// - getDefaultTraceProvider
//
// This global variable is not thread safe
var global_tracer_provider: ?TracerProvider = null;

/// Set the default TracerProvider to the provided implementation
///
/// # Concurrency
/// This api is not thread-safe. Its intended to be called once during application
/// initialization
pub fn setDefaultTracerProvider(tracer_provider: TracerProvider) void {
    global_tracer_provider = tracer_provider;
}

/// Unset the default TracerProvider
///
/// # Concurrency
/// This api is not thread-safe.
pub fn unsetDefaultTracerProvider() void {
    global_tracer_provider = null;
}

/// Get the default TracerProvider, if any.
///
/// # Concurrency
/// This api is not thread-safe.
pub fn getDefaultTracerProvider() *?TracerProvider {
    return &global_tracer_provider;
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
                attributes: []attribute.Attribute,
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
        attributes: []attribute.Attribute,
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
        ?context.Context,
        ?span.Kind,
        []attribute.Attribute,
        []span.Link,
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
                ctx: ?context.Context,
                kind: ?span.Kind,
                attrs: []attribute.Attribute,
                links: []span.Link,
                start: ?u64,
            ) span.Span {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.pointer.child.createSpan, .{
                    self,
                    name,
                    ctx,
                    kind,
                    attrs,
                    links,
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
        ctx: ?context.Context,
        kind: ?span.Kind,
        attrs: []attribute.Attribute,
        links: []span.Link,
        start: ?u64,
    ) span.Span {
        return self.createSpanFn(
            self.ptr,
            name,
            ctx,
            kind,
            attrs,
            links,
            start,
        );
    }
};
