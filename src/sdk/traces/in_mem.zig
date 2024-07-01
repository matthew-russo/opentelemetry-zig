const std = @import("std");

const attribute = @import("../../api/attribute.zig");
const context = @import("../../api/context.zig");
const trace_api = @import("../../api/traces.zig");

pub const InMemoryTracerProvider = struct {
    const Self = @This();

    allocator: std.mem.allocator,

    pub fn init(allocator: std.mem.allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn getTracer(
        self: *Self,
        name: []const u8,
        version: ?[]const u8,
        schema_url: ?[]const u8,
        attributes: []attribute.Attribute,
    ) trace_api.Tracer {
        // TODO [matthew-russo] handle allocation errors
        const tracer = self.allocator.create() catch unreachable;
        tracer.* = InMemoryTracer{
            .name = name,
            .version = version,
            .schema_url = schema_url,
            .attributes = attributes,
        };
        // TODO [matthew-russo] there is no mechanism to clean up
        // the allocated memory once we're done with the Tracer
        return trace_api.Tracer.init(tracer);
    }
};

pub const InMemoryTracer = struct {
    const Self = @This();

    name: []const u8,
    version: ?[]const u8,
    schema_url: ?[]const u8,
    attributes: []attribute.Attribute,

    pub fn createSpan(
        self: *Self,
        name: []const u8,
        ctx: ?context.Context,
        maybe_kind: ?trace_api.Kind,
        attrs: []attribute.Attribute,
        links: []trace_api.Link,
        maybe_start: ?u64,
    ) trace_api.Span {
        _ = self;

        const kind = if (maybe_kind) |k| k else trace_api.Kind.Internal;
        const start: u64 = if (maybe_start) |s| s else blk: {
            const nanosecs: u128 = @intCast(std.time.nanoTimestamp());
            const maxU64: u64 = std.math.maxInt(u64);
            const maxU64AsU128: u128 = @intCast(maxU64);
            std.debug.assert(nanosecs <= maxU64AsU128);
            break :blk @truncate(nanosecs);
        };

        return trace_api.Span{
            .name = name,
            .ctx = ctx,
            .parent = null,
            .kind = kind,
            .start = start,
            .end = 0,
            .attrs = attrs,
            .links = links,
            .events = undefined,
            .status = trace_api.Status.Unset,
        };
    }
};
