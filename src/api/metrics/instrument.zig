const attribute = @import("../attribute.zig");

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
