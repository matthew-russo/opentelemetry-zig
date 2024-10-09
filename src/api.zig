pub const attribute = @import("./api/attribute.zig");
pub const trace = @import("./api/trace.zig");

pub const Attribute = attribute.Attribute;
pub const Resource = @import("./api/Resource.zig");

const root = @import("root");
pub const options: Options = if (@hasDecl(root, "opentelemetry_options"))
    root.opentelemetry_options
else
    .{};

pub const Options = struct {
    enable: bool = true,
    context_max_types: usize = 8,
    context_size: usize = 32,
    check_context_detach_order: bool = std.debug.runtime_safety,
    tracer_provider: type = trace.VoidTracerProvider,
};

pub const InstrumentationScope = struct {
    name: []const u8,
    version: ?[]const u8 = null,
    /// since 1.4.0
    schema_url: ?[]const u8 = null,
    /// since 1.13.0
    attributes: ?[]const Attribute = null,
};

pub const Context = struct {
    /// This should not be accessed directly.
    prev_context: ?*const Context,
    /// This should not be accessed directly.
    value_exists: std.StaticBitSet(options.context_max_types),
    /// This should not be accessed directly.
    bytes: [options.context_size]u8,

    const TypeOffset = struct {
        name: [*:0]const u8,
        offset: u32,
    };

    threadlocal var type_offsets: std.BoundedArray(TypeOffset, options.context_max_types) = .{};
    threadlocal var next_type_offset: u32 = 0;

    fn getTypeOffset(T: type) struct { u32, u32 } {
        for (type_offsets.slice(), 0..) |type_offset, type_index| {
            if (type_offset.name == @typeName(T)) {
                return .{ @intCast(type_index), @intCast(type_offset.offset) };
            }
        }
        const next_aligned_offset = std.mem.alignForward(u32, next_type_offset, @alignOf(T));
        if (next_aligned_offset + @sizeOf(T) >= options.context_size) {
            @panic("Could not allocate space in Context for type " ++ @typeName(T));
        }

        const index = type_offsets.len;
        const type_offset = TypeOffset{ .name = @typeName(T), .offset = next_aligned_offset };
        type_offsets.append(type_offset) catch @panic("Too many types put in Context. " ++ @typeName(T));

        next_type_offset = next_aligned_offset + @sizeOf(T);
        return .{ @intCast(index), @intCast(type_offset.offset) };
    }

    pub fn getValue(context: Context, T: type) ?T {
        const index, const offset = getTypeOffset(T);

        if (context.value_exists.isSet(index)) {
            return std.mem.bytesToValue(T, context.bytes[offset..][0..@sizeOf(T)]);
        }

        return null;
    }

    pub fn withValue(context: Context, T: type, value: T) Context {
        const index, const offset = getTypeOffset(T);

        var new_context = context;

        const new_context_value_ptr = std.mem.bytesAsValue(T, new_context.bytes[offset..][0..@sizeOf(T)]);
        new_context_value_ptr.* = value;
        new_context.value_exists.set(index);

        return new_context;
    }

    const BASE_CONTEXT: Context = .{
        .prev_context = null,
        .value_exists = std.StaticBitSet(options.context_max_types).initEmpty(),
        .bytes = undefined,
    };
    threadlocal var current_context: *const Context = &BASE_CONTEXT;

    pub const AttachToken = if (options.check_context_detach_order)
        struct { prev_context: ?*const Context }
    else
        void;

    pub fn current() *const Context {
        return current_context;
    }

    pub fn attach(context: *const Context) AttachToken {
        const prev_context = current_context;
        current_context = context;

        if (options.check_context_detach_order) {
            return .{ .prev_context = prev_context };
        }
    }

    /// Returns true if the AttachToken did not match the previous scope.
    pub fn detach(context: *const Context, token: AttachToken) bool {
        current_context = context.prev_context;
        if (options.check_context_detach_order) {
            if (context.prev_context != token) {
                std.log.debug("detach token did not match prev_context", .{});
                return true;
            }
            return false;
        }
        return false;
    }
};

comptime {
    if (@import("builtin").is_test) {
        _ = trace;
    }
}

const builtin = @import("builtin");
const std = @import("std");
