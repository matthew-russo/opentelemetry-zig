const attribute = @import("../attribute.zig");
const instrument = @import("instrument.zig");
const meter = @import("meter.zig");

pub const MeterProvider = struct {
    const Self = @This();

    ptr: *anyopaque,

    getMeterFn: *const fn (*anyopaque, []const u8, ?[]const u8, ?[]const u8, []attribute.Attribute) meter.Meter,

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
        if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

        const gen = struct {
            pub fn getMeterImpl(
                pointer: *anyopaque,
                name: []const u8,
                version: ?[]const u8,
                schema_url: ?[]const u8,
                attributes: []attribute.Attribute,
            ) meter.Meter {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.getMeter, .{ self, name, version, schema_url, attributes });
            }
        };

        return .{
            .ptr = ptr,
            .getMeterFn = gen.getMeterImpl,
        };
    }

    pub fn getMeter(
        self: *Self,
        name: []const u8,
        version: ?[]const u8,
        schema_url: ?[]const u8,
        attributes: []attribute.Attribute,
    ) meter.Meter {
        return self.getMeterFn(self.ptr, name, version, schema_url, attributes);
    }
};

pub const Meter = struct {
    const Self = @This();

    ptr: *anyopaque,

    // paremeters for all are:
    // - name
    // - (optional) unit
    // - (optional) description
    // - (optional) advisories
    createCounterFn: *const fn (*anyopaque, []const u8, ?[]const u8, ?[]const u8, ?[]const instrument.AdvisoryParameter) instrument.Counter,
    createAsyncCounterFn: *const fn (*anyopaque, []const u8, ?[]const u8, ?[]const u8, ?[]const instrument.AdvisoryParameter) instrument.AsynchronousCounter,
    createHistogramFn: *const fn (*anyopaque, []const u8, ?[]const u8, ?[]const u8, ?[]const instrument.AdvisoryParameter) instrument.Histogram,
    createGaugeFn: *const fn (*anyopaque, []const u8, ?[]const u8, ?[]const u8, ?[]const instrument.AdvisoryParameter) instrument.Gauge,
    createAsyncGaugeFn: *const fn (*anyopaque, []const u8, ?[]const u8, ?[]const u8, ?[]const instrument.AdvisoryParameter) instrument.AsynchronousGauge,
    createUpDownCounterFn: *const fn (*anyopaque, []const u8, ?[]const u8, ?[]const u8, ?[]const instrument.AdvisoryParameter) instrument.UpDownCounter,
    createAsyncUpDownCounterFn: *const fn (*anyopaque, []const u8, ?[]const u8, ?[]const u8, ?[]const instrument.AdvisoryParameter) instrument.AsynchronousUpDownCounter,

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
        if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

        const gen = struct {
            pub fn createCounterImpl(
                pointer: *anyopaque,
                name: []const u8,
                unit: ?[]const u8,
                description: ?[]const u8,
                advisories: ?[]instrument.AdvisoryParameter,
            ) instrument.Counter {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.createCounter, .{ self, name, unit, description, advisories });
            }

            pub fn createAsyncCounterImpl(
                pointer: *anyopaque,
                name: []const u8,
                unit: ?[]const u8,
                description: ?[]const u8,
                advisories: ?[]instrument.AdvisoryParameter,
            ) instrument.AsynchronousCounter {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.createAsyncCounter, .{ self, name, unit, description, advisories });
            }

            pub fn createHistogramImpl(
                pointer: *anyopaque,
                name: []const u8,
                unit: ?[]const u8,
                description: ?[]const u8,
                advisories: ?[]instrument.AdvisoryParameter,
            ) instrument.Histogram {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.createHistogram, .{ self, name, unit, description, advisories });
            }

            pub fn createGaugeImpl(
                pointer: *anyopaque,
                name: []const u8,
                unit: ?[]const u8,
                description: ?[]const u8,
                advisories: ?[]instrument.AdvisoryParameter,
            ) instrument.Gauge {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.createGauge, .{ self, name, unit, description, advisories });
            }

            pub fn createAsyncGaugeImpl(
                pointer: *anyopaque,
                name: []const u8,
                unit: ?[]const u8,
                description: ?[]const u8,
                advisories: ?[]instrument.AdvisoryParameter,
            ) instrument.AsynchronousGauge {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.createAsyncGauge, .{ self, name, unit, description, advisories });
            }

            pub fn createUpDownCounterImpl(
                pointer: *anyopaque,
                name: []const u8,
                unit: ?[]const u8,
                description: ?[]const u8,
                advisories: ?[]instrument.AdvisoryParameter,
            ) instrument.UpDownCounter {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.createUpDownCounter, .{ self, name, unit, description, advisories });
            }

            pub fn createAsyncUpDownCounterImpl(
                pointer: *anyopaque,
                name: []const u8,
                unit: ?[]const u8,
                description: ?[]const u8,
                advisories: ?[]instrument.AdvisoryParameter,
            ) instrument.AsyncUpDownCounter {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.Pointer.child.createAsyncUpDownCounter, .{ self, name, unit, description, advisories });
            }
        };

        return .{
            .ptr = ptr,
            .createCounterFn = gen.counterImpl,
            .createAsyncCounterFn = gen.asyncCounterImpl,
            .createHistogramFn = gen.histogramImpl,
            .createGaugeFn = gen.gaugeImpl,
            .createAsyncGaugeFn = gen.asyncGaugeImpl,
            .createUpDownCounterFn = gen.upDownCounterImpl,
            .createAsyncUpDownCounterFn = gen.asyncUpDownCounterImpl,
        };
    }

    pub fn createCounter(
        self: *Self,
        name: []const u8,
        unit: ?[]const u8,
        description: ?[]const u8,
        advisories: ?[]instrument.AdvisoryParameter,
    ) instrument.Counter {
        return self.createCounterFn(self.ptr, name, unit, description, advisories);
    }

    pub fn createAsyncCounter(
        self: *Self,
        name: []const u8,
        unit: ?[]const u8,
        description: ?[]const u8,
        advisories: ?[]instrument.AdvisoryParameter,
    ) instrument.AsyncCounter {
        return self.createAsyncCounterFn(self.ptr, name, unit, description, advisories);
    }

    pub fn createHistogram(
        self: *Self,
        name: []const u8,
        unit: ?[]const u8,
        description: ?[]const u8,
        advisories: ?[]instrument.AdvisoryParameter,
    ) instrument.Histogram {
        return self.createHistogramFn(self.ptr, name, unit, description, advisories);
    }

    pub fn createGauge(
        self: *Self,
        name: []const u8,
        unit: ?[]const u8,
        description: ?[]const u8,
        advisories: ?[]instrument.AdvisoryParameter,
    ) instrument.Gauge {
        return self.createGaugeFn(self.ptr, name, unit, description, advisories);
    }

    pub fn createAsyncGauge(
        self: *Self,
        name: []const u8,
        unit: ?[]const u8,
        description: ?[]const u8,
        advisories: ?[]instrument.AdvisoryParameter,
    ) instrument.AsyncGauge {
        return self.createAsyncGaugeFn(self.ptr, name, unit, description, advisories);
    }

    pub fn createUpDownCounter(
        self: *Self,
        name: []const u8,
        unit: ?[]const u8,
        description: ?[]const u8,
        advisories: ?[]instrument.AdvisoryParameter,
    ) instrument.UpDownCounter {
        return self.createUpDownCounterFn(self.ptr, name, unit, description, advisories);
    }

    pub fn createAsyncUpDownCounter(
        self: *Self,
        name: []const u8,
        unit: ?[]const u8,
        description: ?[]const u8,
        advisories: ?[]instrument.AdvisoryParameter,
    ) instrument.AsyncUpDownCounter {
        return self.createAsyncUpDownCounterFn(self.ptr, name, unit, description, advisories);
    }
};

pub const AdvisoryParameter = union(enum) {
    explicit_bucket_boundaries: []const f64,
    attributes: []const attribute.Attribute,
};

pub const Kind = enum {
    counter,
    async_counter,
    histogram,
    gauge,
    async_gauge,
    up_down_counter,
    async_up_down_counter,
};

pub const Instrument = struct {
    name: []const u8,
    kind: Kind,
    unit: ?[]const u8,
    description: ?[]const u8,
    advisory: ?[]const u8,
};

pub const Counter = struct {
    const Self = @This();

    instrument: Instrument,
    value: u64,

    pub fn add(self: Self, to_add: u64, attrs: ?[]const attribute.Attribute) void {
        _ = self;
        _ = to_add;
        _ = attrs;
    }
};

pub const AsynchronousCounter = struct {
    const Self = @This();

    instrument: Instrument,
    value: u64,
};

pub const Histogram = struct {
    const Self = @This();

    instrument: Instrument,
    value: u64,

    pub fn record(self: Self, to_record: u64, attrs: ?[]const attribute.Attribute) void {
        _ = self;
        _ = to_record;
        _ = attrs;
    }
};

pub const Gauge = struct {
    const Self = @This();

    instrument: Instrument,
    value: u64,

    pub fn record(self: Self, to_record: u64, attrs: ?[]const attribute.Attribute) void {
        _ = self;
        _ = to_record;
        _ = attrs;
    }
};

pub const AsynchronousGauge = struct {
    const Self = @This();

    instrument: Instrument,
    value: u64,
};
