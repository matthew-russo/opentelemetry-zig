const otel = @import("opentelemetry-sdk");

pub const opentelemetry_options = otel.api.Options{
    .meter_provider = stderrMeterProvider,
};

pub const StdErrMeter = struct {
    scope: otel.api.InstrumentationScope,
    up_down_counters_i64: std.BoundedArray(UpDownCounter(i64), 8),

    pub const METER_VTABLE = &otel.api.metrics.Meter.VTable{
        .create_up_down_counter_i64 = StdErrMeter.UpDownCounter(i64).stderr_meter_create,

        .create_counter_u64 = undefined,
        .create_counter_f64 = undefined,

        .create_observable_counter_u64 = undefined,
        .create_observable_counter_f64 = undefined,

        .create_histogram_u64 = undefined,
        .create_histogram_f64 = undefined,

        .create_gauge_u64 = undefined,
        .create_gauge_f64 = undefined,

        .create_observable_gauge_u64 = undefined,
        .create_observable_gauge_f64 = undefined,

        .create_up_down_counter_f64 = undefined,

        .create_observable_up_down_counter_u64 = undefined,
        .create_observable_up_down_counter_f64 = undefined,
    };

    fn update(this: *@This()) void {
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        const stderr = std.io.getStdErr();
        stderr.writer().print("meter({s}):", .{this.scope.name}) catch {};
        for (this.up_down_counters_i64.slice()) |counter| {
            if (counter.unit) |unit| {
                stderr.writer().print(" {s} = {} {s};", .{ counter.name, counter.accum, unit }) catch {};
            } else {
                stderr.writer().print(" {s} = {};", .{ counter.name, counter.accum }) catch {};
            }
        }
        stderr.writer().print("\n", .{}) catch {};
    }

    fn UpDownCounter(T: type) type {
        return struct {
            meter: *StdErrMeter,
            name: []const u8,
            unit: ?[]const u8,
            accum: T,

            pub const UP_DOWN_COUNTER_VTABLE = &otel.api.metrics.UpDownCounter(T).VTable{
                .enabled = up_down_counter_enabled,
                .add = up_down_counter_add,
            };

            fn stderr_meter_create(stderr_meter_userdata: ?*anyopaque, comptime name: []const u8, comptime options: otel.api.metrics.UpDownCounter(T).CreateOptions) otel.api.metrics.UpDownCounter(T) {
                const stderr_meter: *StdErrMeter = @ptrCast(@alignCast(stderr_meter_userdata));
                const this = stderr_meter.up_down_counters_i64.addOne() catch return otel.api.metrics.UpDownCounter(i64).NULL;
                this.* = .{
                    .meter = stderr_meter,
                    .name = name,
                    .unit = options.unit,
                    .accum = 0,
                };
                return .{ .ptr = this, .vtable = UP_DOWN_COUNTER_VTABLE };
            }

            fn up_down_counter_enabled(_: ?*anyopaque, _: otel.api.metrics.UpDownCounter(T).EnabledOptions) bool {
                return true;
            }

            fn up_down_counter_add(this_opaque: ?*anyopaque, value: T, attributes: ?[]const otel.api.Attribute) void {
                const this: *@This() = @ptrCast(@alignCast(this_opaque));
                _ = attributes;
                this.accum += value;
                this.meter.update();
            }
        };
    }
};

pub fn stderrMeterProvider(comptime scope: otel.api.InstrumentationScope) otel.api.metrics.Meter {
    const global_value_struct = struct {
        var stderr_meter: StdErrMeter = .{
            .scope = scope,
            .up_down_counters_i64 = .{},
        };
    };
    return .{ .ptr = &global_value_struct.stderr_meter, .vtable = StdErrMeter.METER_VTABLE };
}

fn initTelemetry(allocator: std.mem.Allocator) !void {
    var resource = try otel.Resource.detect(allocator, .{});
    errdefer resource.deinit(allocator);

    const simple_span_processor = try otel.trace.SpanProcessor.Simple.create(allocator, .{});
    errdefer simple_span_processor.spanProcessor().shutdown();

    const batch_processor = try otel.trace.SpanProcessor.Batching.create(allocator, .{});
    errdefer batch_processor.spanProcessor().shutdown();

    const stderr_exporter = try otel.exporter.StdErr.create(allocator, .{});
    errdefer stderr_exporter.spanExporter().shutdown();

    const otlp_exporter = try otel.exporter.OpenTelemetry.create(allocator, .{});
    errdefer otlp_exporter.spanExporter().shutdown();

    try otel.trace.DynamicTracerProvider.init(allocator, .{
        .resource = resource,
        .pipelines = &.{
            .{
                .processor = batch_processor.spanProcessor(),
                .exporter = otlp_exporter.spanExporter(),
            },
            .{
                .processor = simple_span_processor.spanProcessor(),
                .exporter = stderr_exporter.spanExporter(),
            },
        },
    });
}

pub const MeteredAllocator = struct {
    child_allocator: std.mem.Allocator,
    bytes_allocated_counter: otel.api.metrics.UpDownCounter(i64),
    num_allocations_counter: otel.api.metrics.UpDownCounter(i64),

    const meter = otel.api.metrics.getMeter(.{ .name = "zig.opentelemetry.examples.MeteredAllocator" });

    pub fn init(child_allocator: std.mem.Allocator) @This() {
        return .{
            .child_allocator = child_allocator,
            .bytes_allocated_counter = meter.createUpDownCounterI64("bytes_allocated", .{
                .unit = "bytes",
            }),
            .num_allocations_counter = meter.createUpDownCounterI64("num_allocations", .{}),
        };
    }

    const ALLOCATOR_VTABLE = &std.mem.Allocator.VTable{
        .alloc = allocator_alloc,
        .resize = allocator_resize,
        .free = allocator_free,
    };

    pub fn allocator(this: *@This()) std.mem.Allocator {
        return .{ .ptr = this, .vtable = ALLOCATOR_VTABLE };
    }

    fn allocator_alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
        const this: *@This() = @ptrCast(@alignCast(ctx));
        _ = ret_addr;
        const allocation = this.child_allocator.vtable.alloc(this.child_allocator.ptr, len, ptr_align, 0);
        if (allocation) |_| {
            this.bytes_allocated_counter.add(@intCast(len), null);
            this.num_allocations_counter.add(1, null);
        }
        return allocation;
    }

    fn allocator_resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
        const this: *@This() = @ptrCast(@alignCast(ctx));
        _ = ret_addr;
        const result = this.child_allocator.vtable.resize(this.child_allocator.ptr, buf, buf_align, new_len, 0);
        if (result) {
            const old_len: i64 = @intCast(buf.len);
            const cur_len: i64 = @intCast(new_len);
            this.bytes_allocated_counter.add(cur_len - old_len, null);
        }
        return result;
    }

    fn allocator_free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
        const this: *@This() = @ptrCast(@alignCast(ctx));
        const ilen: i64 = @intCast(buf.len);
        this.bytes_allocated_counter.add(-ilen, null);
        this.num_allocations_counter.add(-1, null);
        this.child_allocator.vtable.free(this.child_allocator.ptr, buf, buf_align, ret_addr);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var metered_allocator = MeteredAllocator.init(gpa.allocator());

    const allocator = metered_allocator.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("usage: {s} <number of allocations> <size of allocation>\n", .{args[0]});
        std.process.exit(1);
    }

    const number_of_allocations = try std.fmt.parseInt(usize, args[1], 10);
    const size_of_allocations = try std.fmt.parseInt(usize, args[2], 10);

    var allocations = std.ArrayList([]u8).init(allocator);
    defer {
        for (allocations.items) |alloc| {
            allocator.free(alloc);
        }
        allocations.deinit();
    }
    for (0..number_of_allocations) |_| {
        const mem = try allocator.alloc(u8, size_of_allocations);
        errdefer allocator.free(mem);
        try allocations.append(mem);
    }
}

const std = @import("std");
