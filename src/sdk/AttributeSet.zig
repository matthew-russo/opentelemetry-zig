//! A self contained set of attributes.
//!
//! Converts standard attribute strings into an enum type with statically allocated strings.
//!
//! Owns all the runtime memory it references. Must be passed the same allocator it was initialized with.

kv: KV = .{},
string_table: std.ArrayListUnmanaged(u8) = .{},
value_table: std.ArrayListUnmanaged(u8) = .{},
dropped_attribute_count: u32 = 0,

const KV = std.ArrayHashMapUnmanaged(Key, Value, StringTableContext, false);

pub const Limits = struct {
    count_limit: usize = 128,
    max_string_bytes: usize = 1024,
    max_value_bytes: usize = 1024,
    value_length_limit: ?usize = null,
};

pub fn sizeRequiredForLimits(limits: Limits) usize {
    // this is not accurate, hopefully it's close enough
    const bytes_required_for_kv = @sizeOf(KV) + limits.count_limit * (@sizeOf(Key) + @sizeOf(Value));
    return 2 * (bytes_required_for_kv + limits.max_string_bytes + limits.max_value_bytes);
}

pub fn ensureTotalCapacity(this: *@This(), allocator: std.mem.Allocator, limits: Limits) !void {
    try this.kv.ensureTotalCapacityContext(allocator, limits.count_limit, StringTableContext{ .string_table = this.string_table.items });
    try this.string_table.ensureTotalCapacity(allocator, limits.max_string_bytes);
    try this.value_table.ensureTotalCapacity(allocator, limits.max_value_bytes);
}

pub fn reset(this: *@This()) void {
    this.kv.clearRetainingCapacity();
    this.string_table.clearRetainingCapacity();
    this.value_table.clearRetainingCapacity();
    this.dropped_attribute_count = 0;
}

pub const Size = struct {
    attributes_count: usize,
    string_table_bytes: usize,
    value_table_bytes: usize,
};

pub fn sizeRequiredForList(attributes: []const api.Attribute) Size {
    var total_key_bytes: usize = 0;
    var total_value_bytes: usize = 0;
    for (attributes) |attribute| {
        switch (attribute) {
            .standard => {},
            .dynamic => |d| total_key_bytes += d.key.len,
        }
        const dynamic_value = switch (attribute) {
            .standard => |standard_arg| standard_arg.asDynamicValue(),
            .dynamic => |d| d.value,
        };
        total_value_bytes += sizeRequiredForDynamicValue(dynamic_value);
    }
    return .{
        .attributes_count = attributes.len,
        .string_table_bytes = total_key_bytes,
        .value_table_bytes = total_value_bytes,
    };
}

pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
    this.kv.deinit(allocator);
    this.string_table.deinit(allocator);
    this.value_table.deinit(allocator);
}

pub fn clone(this: @This(), allocator: std.mem.Allocator) !@This() {
    var kv_clone = try this.kv.cloneContext(allocator, .{ .string_table = this.string_table.items });
    errdefer kv_clone.deinit(allocator);

    var string_table_clone = try this.string_table.clone(allocator);
    errdefer string_table_clone.deinit(allocator);

    var value_table_clone = try this.value_table.clone(allocator);
    errdefer value_table_clone.deinit(allocator);

    return .{
        .kv = kv_clone,
        .string_table = string_table_clone,
        .value_table = value_table_clone,
    };
}

pub fn put(this: *@This(), attribute: api.Attribute) void {
    if (this.kv.count() + 1 > this.kv.capacity()) {
        this.dropped_attribute_count += 1;
        return;
    }

    const dynamic_value = switch (attribute) {
        .standard => |standard| standard.asDynamicValue(),
        .dynamic => |dynamic| dynamic.value,
    };

    // write the value into the value table, but leave them in the unused capacity slice until
    // we verify that we can fit the new key
    const value_start_index = this.value_table.items.len;
    const unused_value_bytes = this.value_table.unusedCapacitySlice();
    var value_end_index: usize = 0;
    const value: Value = switch (dynamic_value) {
        .string => |s| blk: {
            if (s.len > unused_value_bytes.len) {
                this.dropped_attribute_count += 1;
                return;
            }
            @memcpy(unused_value_bytes[0..s.len], s);
            value_end_index += s.len;
            break :blk .{ .string = .{ .idx = @intCast(value_start_index), .len = @intCast(s.len) } };
        },
        .boolean => |b| .{ .boolean = b },
        .double => |d| .{ .double = d },
        .integer => |i| .{ .integer = i },

        .string_array => |array| blk: {
            for (array, 0..) |string, i| {
                if (value_end_index + string.len + 1 > unused_value_bytes.len) {
                    this.dropped_attribute_count += 1;
                    return;
                }
                if (i > 0) {
                    unused_value_bytes[value_end_index] = 0;
                    value_end_index += 1;
                }
                @memcpy(unused_value_bytes[value_end_index..][0..string.len], string);
                value_end_index += string.len;
            }
            break :blk .{ .string_array = .{ .idx = @intCast(value_start_index), .len = @intCast(value_end_index - value_start_index) } };
        },
        .boolean_array => |src_array| blk: {
            if (src_array.len > unused_value_bytes.len) {
                this.dropped_attribute_count += 1;
                return;
            }
            const dst_array = unused_value_bytes[value_end_index..][0..src_array.len];
            for (dst_array, src_array) |*dst, src| {
                dst.* = @intFromBool(src);
            }

            value_end_index += src_array.len;

            break :blk .{ .boolean_array = .{ .idx = @intCast(value_start_index), .len = @intCast(src_array.len) } };
        },
        .double_array => |array| blk: {
            const aligned_start = std.mem.alignForward(usize, value_start_index, 8);
            if (aligned_start + array.len * @sizeOf(f64) > unused_value_bytes.len) {
                this.dropped_attribute_count += 1;
                return;
            }

            value_end_index = aligned_start;
            const table_bytes = unused_value_bytes[aligned_start..];
            const dst_array = @as([*]f64, @ptrCast(@alignCast(table_bytes.ptr)))[0..array.len];
            @memcpy(dst_array, array);
            value_end_index += array.len * @sizeOf(f64);

            break :blk .{ .double_array = .{ .idx = @intCast(aligned_start), .len = @intCast(value_end_index - aligned_start) } };
        },
        .integer_array => |array| blk: {
            const aligned_start = std.mem.alignForward(usize, value_start_index, 8);
            if (aligned_start + array.len * @sizeOf(i64) > unused_value_bytes.len) {
                this.dropped_attribute_count += 1;
                return;
            }

            value_end_index = aligned_start;
            const table_bytes = unused_value_bytes[aligned_start..];
            const dst_array = @as([*]i64, @ptrCast(@alignCast(table_bytes.ptr)))[0..array.len];
            @memcpy(dst_array, array);
            value_end_index += array.len * @sizeOf(f64);

            break :blk .{ .integer_array = .{ .idx = @intCast(aligned_start), .len = @intCast(value_end_index - aligned_start) } };
        },
    };

    const unused_string_bytes = this.string_table.unusedCapacitySlice();
    var string_end_index: usize = 0;
    const key = write_key_string: {
        switch (attribute) {
            .standard => |standard| {
                break :write_key_string Key{ .type = .standard, .data = .{ .standard = standard } };
            },
            .dynamic => |dynamic| {
                if (dynamic.key.len == 0) return;
                if (std.meta.stringToEnum(api.attribute.Standard.Name, dynamic.key)) |standard_key| {
                    break :write_key_string Key{ .type = .standard, .data = .{ .standard = standard_key } };
                }
                if (dynamic.key.len + 1 > unused_string_bytes.len) {
                    this.dropped_attribute_count += 1;
                    return;
                }
                @memcpy(unused_value_bytes[0..dynamic.key.len], dynamic.key);
                unused_value_bytes[dynamic.key.len] = 0;
                string_end_index += dynamic.key.len + 1;

                break :write_key_string Key{ .type = .custom, .data = .{ .custom = @enumFromInt(this.string_table.items.len) } };
            },
        }
    };

    // finalize writes
    this.string_table.items.len += string_end_index;
    this.value_table.items.len += value_end_index;
    this.kv.putAssumeCapacityContext(key, value, .{ .string_table = this.string_table.items });
}

/// Asserts that all attribute keys are larger than 0.
pub fn fromList(allocator: std.mem.Allocator, list: []const api.Attribute) !@This() {
    var set: @This() = .{};
    errdefer set.deinit(allocator);
    for (list) |attr| {
        const context = StringTableContext{ .string_table = set.string_table.items };
        const gop = if (attr == .standard)
            try set.kv.getOrPutContext(allocator, .{ .type = .standard, .data = .{ .standard = attr.standard } }, context)
        else get_dynamic: {
            std.debug.assert(attr.dynamic.key.len > 0);
            const adapter = StringTableAdapter{ .string_table = set.string_table.items };
            const gop = try set.kv.getOrPutContextAdapted(allocator, attr.dynamic.key, adapter, context);
            if (!gop.found_existing) {
                if (std.meta.stringToEnum(api.attribute.Standard.Name, attr.dynamic.key)) |standard_key| {
                    gop.key_ptr.* = .{ .type = .standard, .data = .{ .standard = standard_key } };
                } else {
                    try set.string_table.ensureUnusedCapacity(allocator, attr.dynamic.key.len + 1);
                    const index = set.string_table.items.len;
                    set.string_table.appendSliceAssumeCapacity(attr.dynamic.key);
                    set.string_table.appendAssumeCapacity(0);
                    gop.key_ptr.* = .{ .type = .custom, .data = .{ .custom = @enumFromInt(index) } };
                }
            }
            break :get_dynamic gop;
        };

        const dynamic_value = switch (attr) {
            .standard => |standard| standard.asDynamicValue(),
            .dynamic => |dynamic| dynamic.value,
        };

        switch (dynamic_value) {
            .string => |s| {
                const start_index: u32 = @intCast(set.value_table.items.len);
                try set.value_table.appendSlice(allocator, s);
                gop.value_ptr.* = .{ .string = .{ .idx = start_index, .len = @intCast(s.len) } };
            },
            .boolean => |b| gop.value_ptr.* = .{ .boolean = b },
            .double => |d| gop.value_ptr.* = .{ .double = d },
            .integer => |i| gop.value_ptr.* = .{ .integer = i },

            .string_array => |array| {
                const start_index: u32 = @intCast(set.value_table.items.len);
                for (array, 0..) |string, i| {
                    if (i > 0) try set.value_table.append(allocator, 0);
                    try set.value_table.appendSlice(allocator, string);
                }
                const len: u32 = @intCast(set.value_table.items.len - start_index);
                gop.value_ptr.* = .{ .string_array = .{ .idx = start_index, .len = len } };
            },
            .boolean_array => |src_array| {
                const start_index: u32 = @intCast(set.value_table.items.len);
                const dst_array = try set.value_table.addManyAsSlice(allocator, src_array.len);
                for (dst_array, src_array) |*dst, src| {
                    dst.* = @intFromBool(src);
                }
                gop.value_ptr.* = .{ .boolean_array = .{ .idx = start_index, .len = @intCast(src_array.len) } };
            },
            .double_array => |array| {
                try set.value_table.resize(allocator, std.mem.alignForward(usize, set.value_table.items.len, 8));

                const start_index: u32 = @intCast(set.value_table.items.len);
                const table_bytes = try set.value_table.addManyAsSlice(allocator, array.len * 8);
                const dst_array = @as([*]f64, @ptrCast(@alignCast(table_bytes.ptr)))[0..array.len];
                @memcpy(dst_array, array);

                const len: u32 = @intCast(set.value_table.items.len - start_index);
                gop.value_ptr.* = .{ .double_array = .{ .idx = start_index, .len = len } };
            },
            .integer_array => |array| {
                try set.value_table.resize(allocator, std.mem.alignForward(usize, set.value_table.items.len, 8));

                const start_index: u32 = @intCast(set.value_table.items.len);
                const table_bytes = try set.value_table.addManyAsSlice(allocator, array.len * 8);
                const dst_array = @as([*]i64, @ptrCast(@alignCast(table_bytes.ptr)))[0..array.len];
                @memcpy(dst_array, array);

                const len: u32 = @intCast(set.value_table.items.len - start_index);
                gop.value_ptr.* = .{ .integer_array = .{ .idx = start_index, .len = len } };
            },
        }
    }
    return set;
}

pub fn sizeRequiredForDynamicValue(value: api.attribute.Dynamic.Value) usize {
    return switch (value) {
        .string => |s| s.len,
        .boolean => 0,
        .double => 0,
        .integer => 0,

        .string_array => |array| blk: {
            // We need len - 1 nul terminators
            var bytes_required = array.len -| 1;
            for (array) |string| {
                bytes_required += string.len;
            }
            break :blk bytes_required;
        },
        .boolean_array => |array| array.len,
        .double_array => |array| array.len * @sizeOf(f64) + @alignOf(f64),
        .integer_array => |array| array.len * @sizeOf(i64) + @alignOf(i64),
    };
}

const StringTableContext = struct {
    string_table: []const u8,

    pub const hashString = std.array_hash_map.hashString;

    pub fn eql(this: @This(), a: Key, b: Key, b_index: usize) bool {
        _ = this;
        _ = b_index;
        return @as(u32, @bitCast(a)) == @as(u32, @bitCast(b));
    }

    pub fn hash(this: @This(), key: Key) u32 {
        const key_str = switch (key.type) {
            .standard => @tagName(key.data.standard),
            .custom => std.mem.span(@as([*:0]const u8, @ptrCast(this.string_table[@intFromEnum(key.data.custom)..].ptr))),
        };
        return hashString(key_str);
    }
};

const StringTableAdapter = struct {
    string_table: []const u8,

    pub const hashString = std.array_hash_map.hashString;

    pub fn eql(this: @This(), a_str: []const u8, b: Key, b_index: usize) bool {
        _ = b_index;
        const b_str = switch (b.type) {
            .standard => @tagName(b.data.standard),
            .custom => std.mem.span(@as([*:0]const u8, @ptrCast(this.string_table[@intFromEnum(b.data.custom)..].ptr))),
        };
        return std.mem.eql(u8, a_str, b_str);
    }

    pub fn hash(this: @This(), key_str: []const u8) u32 {
        _ = this;
        return hashString(key_str);
    }
};

pub const Key = packed struct(u32) {
    type: Key.Type,
    data: Data,

    pub const Type = enum(u1) { standard, custom };

    pub const Data = packed union {
        standard: api.attribute.Standard.Name,
        custom: StringIndex,
    };

    pub const StringIndex = enum(u31) { _ };
};

pub const Value = union(api.attribute.Type) {
    // ------ primitive types ------

    /// A single string. Strings should not contain nul bytes.
    string: Array,
    boolean: bool,
    double: f64,
    integer: i64,

    // --- primitive array types ---

    /// each string separated by a 0
    string_array: Array,
    /// each byte represents a boolean
    boolean_array: Array,
    /// Offset must be aligned to 8. Every 8 bytes represents a 64-bit float.
    double_array: Array,
    /// Offset must be aligned to 8. Every 8 bytes represents a 64-bit integer.
    integer_array: Array,

    pub const Array = extern struct {
        /// The offset into `value_table`
        idx: u32,
        /// Number of bytes in the value's array. How the type is encoded depends on the
        /// value's type.
        len: u32,
    };
};

pub fn getKeyString(this: @This(), key: Key) []const u8 {
    return switch (key.type) {
        .standard => @tagName(key.data.standard),
        .custom => std.mem.span(@as([*:0]const u8, @ptrCast(this.string_table.items[@intFromEnum(key.data.custom)..].ptr))),
    };
}

pub fn getValueBytes(this: @This(), array: Value.Array) []const u8 {
    return this.value_table.items[array.idx..][0..array.len];
}

pub fn format(this: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    try writer.writeAll("{");
    for (this.kv.keys(), this.kv.values()) |key, val| {
        try writer.writeAll(" ");
        try writer.writeAll(this.getKeyString(key));
        try writer.writeAll("=");

        switch (val) {
            .string => |s| try writer.print("\"{}\"", .{std.zig.fmtEscapes(this.getValueBytes(s))}),
            .boolean => |b| try writer.print("{}", .{b}),
            .double => |d| try writer.print("{e}", .{d}),
            .integer => |i| try writer.print("{}", .{i}),

            .string_array => |array| {
                var string_iter = std.mem.splitScalar(u8, this.getValueBytes(array), 0);
                try writer.writeAll("{");
                while (string_iter.next()) |string| {
                    try writer.print(" \"{}\"", .{std.zig.fmtEscapes(string)});
                }
                try writer.writeAll(" }");
            },
            .boolean_array => |array| {
                try writer.writeAll("{");
                for (this.getValueBytes(array)) |byte| {
                    try writer.print(" {}", .{byte != 0});
                }
                try writer.writeAll(" }");
            },
            .double_array => |array| {
                const bytes = this.getValueBytes(array);
                try writer.writeAll("{");
                for (std.mem.bytesAsSlice(f64, bytes)) |double| {
                    try writer.print(" {e}", .{double});
                }
                try writer.writeAll(" }");
            },
            .integer_array => |array| {
                const bytes = this.getValueBytes(array);
                try writer.writeAll("{");
                for (std.mem.bytesAsSlice(i64, bytes)) |integer| {
                    try writer.print(" {d}", .{integer});
                }
                try writer.writeAll(" }");
            },
        }
    }
    try writer.writeAll(" }");
}

pub fn jsonStringify(this: @This(), jw: anytype) !void {
    try jw.beginArray();
    for (this.kv.keys(), this.kv.values()) |key, val| {
        try jw.beginObject();
        try jw.objectField("key");
        try jw.write(this.getKeyString(key));

        try jw.objectField("value");
        try jw.beginObject();
        switch (val) {
            .string => |array| {
                try jw.objectField("stringValue");
                try jw.write(this.getValueBytes(array));
            },
            .boolean => |b| {
                try jw.objectField("boolValue");
                try jw.write(b);
            },
            .double => |d| {
                try jw.objectField("doubleValue");
                try jw.write(d);
            },
            .integer => |i| {
                try jw.objectField("intValue");
                try jw.write(i);
            },
            .string_array => |array| {
                try jw.objectField("arrayValue");
                try jw.beginObject();
                try jw.objectField("values");
                try jw.beginArray();

                var string_iter = std.mem.splitScalar(u8, this.getValueBytes(array), 0);
                while (string_iter.next()) |string| {
                    try jw.beginObject();
                    try jw.objectField("stringValue");
                    try jw.write(string);
                    try jw.endObject();
                }

                try jw.endArray();
                try jw.endObject();
            },
            .boolean_array => |array| {
                try jw.objectField("arrayValue");
                try jw.beginObject();
                try jw.objectField("values");
                try jw.beginArray();
                for (this.getValueBytes(array)) |byte| {
                    try jw.beginObject();
                    try jw.objectField("boolValue");
                    try jw.write(byte != 0);
                    try jw.endObject();
                }
                try jw.endArray();
                try jw.endObject();
            },
            .double_array => |array| {
                try jw.objectField("arrayValue");
                try jw.beginObject();
                try jw.objectField("values");
                try jw.beginArray();

                const bytes = this.getValueBytes(array);
                for (std.mem.bytesAsSlice(f64, bytes)) |double| {
                    try jw.beginObject();
                    try jw.objectField("doubleValue");
                    try jw.write(double);
                    try jw.endObject();
                }

                try jw.endArray();
                try jw.endObject();
            },
            .integer_array => |array| {
                try jw.objectField("arrayValue");
                try jw.beginObject();
                try jw.objectField("values");
                try jw.beginArray();

                const bytes = this.getValueBytes(array);
                for (std.mem.bytesAsSlice(i64, bytes)) |double| {
                    try jw.beginObject();
                    try jw.objectField("intValue");
                    try jw.write(double);
                    try jw.endObject();
                }

                try jw.endArray();
                try jw.endObject();
            },
        }
        try jw.endObject();
        try jw.endObject();
    }
    try jw.endArray();
}

const api = @import("api");
const std = @import("std");
