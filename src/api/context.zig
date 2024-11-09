const std = @import("std");

const span = @import("./span.zig");

threadlocal var current_context: ?Context = null;

pub fn getCurrentContext() *?Context {
    return &current_context;
}

pub fn attachContext(new_ctx: Context) ContextGuard {
    if (getCurrentContext().*) |curr_ctx| {
        const ctx_guard = ContextGuard{
            .prev_ctx = curr_ctx,
            .ctx = new_ctx,
        };
        current_context = new_ctx;
        return ctx_guard;
    } else {
        const ctx_guard = ContextGuard{
            .prev_ctx = null,
            .ctx = new_ctx,
        };
        current_context = new_ctx;
        return ctx_guard;
    }
}

pub fn detachContext(ctx_guard: ContextGuard) void {
    // TODO detect if the provided guard is incorrect

    if (ctx_guard.prev_ctx) |prev_ctx| {
        current_context = prev_ctx;
    } else {
        current_context = null;
    }
}

pub fn clearCurrentContext() void {
    current_context = null;
}

pub const ContextValue = struct {
    value: []const u8,
};

pub const Context = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    span: ?span.Span,
    values: std.StringHashMap(ContextValue),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,

            .span = null,
            .values = std.StringHashMap(ContextValue).init(allocator),
        };
    }

    pub fn initWithSpan(allocator: std.mem.Allocator, s: span.Span) Self {
        return Self{
            .allocator = allocator,

            .span = s,
            .values = std.StringHashMap(ContextValue).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.values.deinit();
    }

    pub fn clone(self: *const Self) Self {
        return Self{
            .allocator = self.allocator,
            .span = self.span,
            // ignore OOMs
            .values = self.values.clone() catch unreachable,
        };
    }

    pub fn withSpan(self: *Self, s: span.Span) Self {
        return Self{
            .allocator = self.allocator,
            .span = s,
            // ignore OOMs
            .values = self.values.clone() catch unreachable,
        };
    }

    pub fn getSpan(self: *Self) ?*span.Span {
        if (self.span) |*s| {
            return s;
        } else {
            return null;
        }
    }

    pub fn getValue(self: *const Self, name: []const u8) ?ContextValue {
        return self.values.get(name);
    }

    pub fn withValue(self: *const Self, name: []const u8, value: ContextValue) Self {
        var new_context = self.clone();
        new_context.setValue(name, value);
        return new_context;
    }

    pub fn attach(self: *Self) ContextGuard {
        return attachContext(self.*);
    }

    // internal mutator, not publicly accessible. users will generate updated
    // contexts via `withValue` which clones the current Context
    fn setValue(self: *Self, name: []const u8, value: ContextValue) void {
        // ignore OOMs
        self.values.put(name, value) catch unreachable;
    }
};

pub const ContextGuard = struct {
    const Self = @This();

    prev_ctx: ?Context,
    ctx: Context,

    pub fn detach(self: *Self) void {
        detachContext(self.*);
    }
};

test "can construct Context" {
    _ = Context.init(std.testing.allocator);
}

test "can construct Context with a Span" {
    _ = Context.initWithSpan(std.testing.allocator, span.Span{
        .name = "test_span",
        .ctx = span.SpanContext.init(
            span.TraceId.invalid(),
            span.SpanId.invalid(),
            span.Flags.init(),
            span.TraceState.init(),
            false, // is_remote
        ),
        .parent = null,
        .kind = span.Kind.Internal,
        .start = 0,
        .end = 1,
        .attrs = undefined,
        .links = undefined,
        .events = undefined,
        .status = span.Status.Unset,
    });
}

test "can fetch the current Span from the Context" {
    var without_span = Context.init(std.testing.allocator);
    try std.testing.expectEqual(without_span.getSpan(), null);

    var with_span = Context.initWithSpan(std.testing.allocator, span.Span{
        .name = "test_span",
        .ctx = span.SpanContext.init(
            span.TraceId.invalid(),
            span.SpanId.invalid(),
            span.Flags.init(),
            span.TraceState.init(),
            false, // is_remote
        ),
        .parent = null,
        .kind = span.Kind.Internal,
        .start = 0,
        .end = 1,
        .attrs = undefined,
        .links = undefined,
        .events = undefined,
        .status = span.Status.Unset,
    });
    const borrowed_span = with_span.getSpan();
    if (borrowed_span) |s| {
        try std.testing.expectEqualStrings(s.name, "test_span");
        try std.testing.expectEqual(s.kind, span.Kind.Internal);
        try std.testing.expectEqual(s.start, 0);
        try std.testing.expectEqual(s.end, 1);
        try std.testing.expectEqual(s.status, span.Status.Unset);
    } else {
        std.debug.panic("span should have been present after constructing with span", .{});
    }
}

test "can insert a value into Context" {
    var ctx = Context.init(std.testing.allocator);
    defer ctx.deinit();
    ctx.setValue("test", ContextValue{ .value = "test_value" });
}

test "can get an inserted value from Context" {
    var ctx = Context.init(std.testing.allocator);
    defer ctx.deinit();
    ctx.setValue("test", ContextValue{ .value = "test_value" });
    const value = ctx.getValue("test").?;
    try std.testing.expectEqualStrings(value.value, "test_value");
}

test "can clone Context" {
    var ctx = Context.init(std.testing.allocator);
    defer ctx.deinit();

    ctx.setValue("before", ContextValue{ .value = "before_value" });
    var value = ctx.getValue("before").?;
    try std.testing.expectEqualStrings(value.value, "before_value");

    var new_ctx = ctx.clone();
    defer new_ctx.deinit();

    new_ctx.setValue("after", ContextValue{ .value = "after_value" });
    if (ctx.getValue("after")) |_| {
        std.debug.panic("original context should not have been updated", .{});
    }

    // cloned context should have both values
    value = new_ctx.getValue("before").?;
    try std.testing.expectEqualStrings(value.value, "before_value");
    value = new_ctx.getValue("after").?;
    try std.testing.expectEqualStrings(value.value, "after_value");
}

test "can associate a Span with a Context" {
    var ctx = Context.init(std.testing.allocator);
    defer ctx.deinit();

    ctx.setValue("before", ContextValue{ .value = "before_value" });
    var value = ctx.getValue("before").?;
    try std.testing.expectEqualStrings(value.value, "before_value");

    var new_ctx = ctx.withSpan(span.Span{
        .name = "test_span",
        .ctx = span.SpanContext.init(
            span.TraceId.invalid(),
            span.SpanId.invalid(),
            span.Flags.init(),
            span.TraceState.init(),
            false, // is_remote
        ),
        .parent = null,
        .kind = span.Kind.Internal,
        .start = 0,
        .end = 1,
        .attrs = undefined,
        .links = undefined,
        .events = undefined,
        .status = span.Status.Unset,
    });
    defer new_ctx.deinit();

    new_ctx.setValue("after", ContextValue{ .value = "after_value" });
    if (ctx.getValue("after")) |_| {
        std.debug.panic("original context should not have been updated", .{});
    }

    // new context should have both values
    value = new_ctx.getValue("before").?;
    try std.testing.expectEqualStrings(value.value, "before_value");
    value = new_ctx.getValue("after").?;
    try std.testing.expectEqualStrings(value.value, "after_value");

    const borrowed_span = new_ctx.getSpan();
    if (borrowed_span) |s| {
        try std.testing.expectEqualStrings(s.name, "test_span");
        try std.testing.expectEqual(s.kind, span.Kind.Internal);
        try std.testing.expectEqual(s.start, 0);
        try std.testing.expectEqual(s.end, 1);
        try std.testing.expectEqual(s.status, span.Status.Unset);
    } else {
        std.debug.panic("span should have been present after constructing with span", .{});
    }
}

test "can immutably generate new Context with value" {
    var ctx = Context.init(std.testing.allocator);
    defer ctx.deinit();
    var new_ctx = ctx.withValue("test", ContextValue{ .value = "test_value" });
    defer new_ctx.deinit();
    if (ctx.getValue("test")) |_| {
        std.debug.panic("original context should not have been updated", .{});
    }
    const value = new_ctx.getValue("test").?;
    try std.testing.expectEqualStrings(value.value, "test_value");
}

test "can attach Context to thread" {
    clearCurrentContext();

    if (getCurrentContext().*) |_| {
        std.debug.panic("current context shouldn't be set yet", .{});
    }

    var ctx = Context.init(std.testing.allocator);
    defer ctx.deinit();
    ctx.setValue("test", ContextValue{ .value = "test_value" });
    _ = ctx.attach();

    if (getCurrentContext().*) |curr_ctx| {
        const value = curr_ctx.getValue("test").?;
        try std.testing.expectEqualStrings(value.value, "test_value");
    }
}

test "can detach Context from a thread" {
    clearCurrentContext();

    if (getCurrentContext().*) |_| {
        std.debug.panic("current context shouldn't be set yet", .{});
    }

    var ctx = Context.init(std.testing.allocator);
    defer ctx.deinit();
    ctx.setValue("test", ContextValue{ .value = "test_value" });
    var guard = ctx.attach();

    if (getCurrentContext().*) |curr_ctx| {
        const value = curr_ctx.getValue("test").?;
        try std.testing.expectEqualStrings(value.value, "test_value");
    } else {
        std.debug.panic("current context should now be set", .{});
    }

    guard.detach();

    if (getCurrentContext().*) |_| {
        std.debug.panic("current context should have been unset by detach", .{});
    }
}

test "detach Context restores prior context" {
    clearCurrentContext();

    if (getCurrentContext().*) |_| {
        std.debug.panic("current context shouldn't be set yet", .{});
    }

    var ctx1 = Context.init(std.testing.allocator);
    defer ctx1.deinit();
    ctx1.setValue("test1", ContextValue{ .value = "test_value1" });
    var guard1 = ctx1.attach();

    var ctx2 = Context.init(std.testing.allocator);
    defer ctx2.deinit();
    ctx2.setValue("test2", ContextValue{ .value = "test_value2" });
    var guard2 = ctx2.attach();

    if (getCurrentContext().*) |curr_ctx| {
        const value = curr_ctx.getValue("test2").?;
        try std.testing.expectEqualStrings(value.value, "test_value2");
    } else {
        std.debug.panic("current context should now be set", .{});
    }

    guard2.detach();

    // current context should have been reset back to the first context
    if (getCurrentContext().*) |curr_ctx| {
        const value = curr_ctx.getValue("test1").?;
        try std.testing.expectEqualStrings(value.value, "test_value1");
    } else {
        std.debug.panic("current context should now be set", .{});
    }

    guard1.detach();
    if (getCurrentContext().*) |_| {
        std.debug.panic("current context should have been unset by detach", .{});
    }
}
