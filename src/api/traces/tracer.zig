const span = @import("span.zig");
const attribute = @import("../attribute.zig");
const context = @import("../context.zig");

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

        if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
        if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

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
                return @call(.always_inline, ptr_info.Pointer.child.createSpan, .{
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
    ) void {
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
