pub const MeterProvider = fn (comptime api.InstrumentationScope) Meter;

pub const getMeter: MeterProvider = api.options.meter_provider;

pub const Meter = struct {
    ptr: ?*anyopaque,
    vtable: ?*const VTable,

    pub const NULL = Meter{ .ptr = null, .vtable = null };

    pub const VTable = struct {
        create_counter_u64: *const fn (?*anyopaque, comptime name: []const u8, comptime Counter(u64).CreateOptions) Counter(u64),
        create_counter_f64: *const fn (?*anyopaque, comptime name: []const u8, comptime Counter(f64).CreateOptions) Counter(f64),

        /// - Callback functions SHOULD be reentrant safe. The SDK expects to evaluate
        ///   callbacks for each Metric independently.
        /// - Callback functions SHOULD NOT take an indefinite amount of time.
        /// - Callback functions SHOULD NOT make duplicate measurements (more than one
        ///   Measurement with the same `attributes`) across all registered callbacks.
        create_observable_counter_u64: *const fn (?*anyopaque, comptime name: []const u8, comptime ObservableCounter(u64).CreateOptions) ObservableCounter(u64),
        create_observable_counter_f64: *const fn (?*anyopaque, comptime name: []const u8, comptime ObservableCounter(f64).CreateOptions) ObservableCounter(f64),

        create_histogram_u64: *const fn (?*anyopaque, comptime name: []const u8, comptime Histogram(u64).CreateOptions) Histogram(u64),
        create_histogram_f64: *const fn (?*anyopaque, comptime name: []const u8, comptime Histogram(f64).CreateOptions) Histogram(f64),

        create_gauge_u64: *const fn (?*anyopaque, comptime name: []const u8, comptime Gauge(u64).CreateOptions) Gauge(u64),
        create_gauge_f64: *const fn (?*anyopaque, comptime name: []const u8, comptime Gauge(f64).CreateOptions) Gauge(f64),

        create_observable_gauge_u64: *const fn (?*anyopaque, comptime name: []const u8, comptime ObservableGauge(u64).CreateOptions) ObservableGauge(u64),
        create_observable_gauge_f64: *const fn (?*anyopaque, comptime name: []const u8, comptime ObservableGauge(f64).CreateOptions) ObservableGauge(f64),

        create_up_down_counter_i64: *const fn (?*anyopaque, comptime name: []const u8, comptime UpDownCounter(i64).CreateOptions) UpDownCounter(i64),
        create_up_down_counter_f64: *const fn (?*anyopaque, comptime name: []const u8, comptime UpDownCounter(f64).CreateOptions) UpDownCounter(f64),

        create_observable_up_down_counter_u64: *const fn (?*anyopaque, comptime name: []const u8, comptime ObservableUpDownCounter(u64).CreateOptions) ObservableUpDownCounter(u64),
        create_observable_up_down_counter_f64: *const fn (?*anyopaque, comptime name: []const u8, comptime ObservableUpDownCounter(f64).CreateOptions) ObservableUpDownCounter(f64),
    };

    pub fn createCounterU64(meter: Meter, comptime name: []const u8, comptime options: Counter(u64).CreateOptions) Counter(u64) {
        const vtable = meter.vtable orelse return Counter(u64).NULL;
        return vtable.create_counter_u64(meter.ptr, name, options);
    }

    pub fn createCounterF64(meter: Meter, comptime name: []const u8, comptime options: Counter(f64).CreateOptions) Counter(f64) {
        const vtable = meter.vtable orelse return Counter(f64).NULL;
        return vtable.create_counter_f64(meter.ptr, name, options);
    }

    /// - Callback functions SHOULD be reentrant safe. The SDK expects to evaluate
    ///   callbacks for each Metric independently.
    /// - Callback functions SHOULD NOT take an indefinite amount of time.
    /// - Callback functions SHOULD NOT make duplicate measurements (more than one
    ///   Measurement with the same `attributes`) across all registered callbacks.
    pub fn createObservableCounterU64(meter: Meter, comptime name: []const u8, comptime options: ObservableCounter(u64).CreateOptions) ObservableCounter(u64) {
        const vtable = meter.vtable orelse return ObservableCounter(u64).NULL;
        return vtable.create_observable_counter_u64(meter.ptr, name, options);
    }

    pub fn createObservableCounterF64(meter: Meter, comptime name: []const u8, comptime options: ObservableCounter(f64).CreateOptions) ObservableCounter(f64) {
        const vtable = meter.vtable orelse return ObservableCounter(f64).NULL;
        return vtable.create_observable_counter_f64(meter.ptr, name, options);
    }

    pub fn createHistogramU64(meter: Meter, comptime name: []const u8, comptime options: Histogram(u64).CreateOptions) Histogram(u64) {
        const vtable = meter.vtable orelse return Histogram(u64).NULL;
        return vtable.create_histogram_u64(meter.ptr, name, options);
    }

    pub fn createHistogramF64(meter: Meter, comptime name: []const u8, comptime options: Histogram(f64).CreateOptions) Histogram(f64) {
        const vtable = meter.vtable orelse return Histogram(f64).NULL;
        return vtable.create_histogram_f64(meter.ptr, name, options);
    }

    pub fn createGaugeU64(meter: Meter, comptime name: []const u8, comptime options: Gauge(u64).CreateOptions) Gauge(u64) {
        const vtable = meter.vtable orelse return Gauge(u64).NULL;
        return vtable.create_gauge_u64(meter.ptr, name, options);
    }

    pub fn createGaugeF64(meter: Meter, comptime name: []const u8, comptime options: Gauge(f64).CreateOptions) Gauge(f64) {
        const vtable = meter.vtable orelse return Gauge(f64).NULL;
        return vtable.create_gauge_f64(meter.ptr, name, options);
    }

    pub fn createObservableGaugeU64(meter: Meter, comptime name: []const u8, comptime options: ObservableGauge(u64).CreateOptions) ObservableGauge(u64) {
        const vtable = meter.vtable orelse return ObservableGauge(u64).NULL;
        return vtable.create_observable_gauge_u64(meter.ptr, name, options);
    }

    pub fn createObservableGaugeF64(meter: Meter, comptime name: []const u8, comptime options: ObservableGauge(f64).CreateOptions) ObservableGauge(f64) {
        const vtable = meter.vtable orelse return ObservableGauge(f64).NULL;
        return vtable.create_observable_gauge_f64(meter.ptr, name, options);
    }

    pub fn createUpDownCounterI64(meter: Meter, comptime name: []const u8, comptime options: UpDownCounter(i64).CreateOptions) UpDownCounter(i64) {
        const vtable = meter.vtable orelse return UpDownCounter(i64).NULL;
        return vtable.create_up_down_counter_i64(meter.ptr, name, options);
    }

    pub fn createUpDownCounterF64(meter: Meter, comptime name: []const u8, comptime options: UpDownCounter(f64).CreateOptions) UpDownCounter(f64) {
        const vtable = meter.vtable orelse return UpDownCounter(f64).NULL;
        return vtable.create_up_down_counter_f64(meter.ptr, name, options);
    }

    pub fn createObservableUpDownCounterU64(meter: Meter, comptime name: []const u8, comptime options: ObservableUpDownCounter(u64).CreateOptions) ObservableUpDownCounter(u64) {
        const vtable = meter.vtable orelse return ObservableUpDownCounter(u64).NULL;
        return vtable.create_observable_up_down_counter_u64(meter.ptr, name, options);
    }

    pub fn createObservableUpDownCounterF64(meter: Meter, comptime name: []const u8, comptime options: ObservableUpDownCounter(f64).CreateOptions) ObservableUpDownCounter(f64) {
        const vtable = meter.vtable orelse return ObservableUpDownCounter(f64).NULL;
        return vtable.create_observable_up_down_counter_f64(meter.ptr, name, options);
    }
};

pub const InstrumentCreateOptions = struct {
    unit: ?[]const u8 = null,
    description: ?[]const u8 = null,
    advisory: ?Advisory = null,

    pub const Advisory = struct {
        explicit_bucket_boundaries: []const f64 = null,
        attributes: ?[]const api.Attribute = null,
    };
};

pub const Instrument = struct {
    ptr: ?*anyopaque,
    vtable: ?*const VTable,

    pub const EnabledOptions = struct {};
    pub const VTable = struct {
        enabled: *const fn (?*anyopaque, EnabledOptions) void,
    };
};

pub fn ObservableResult(T: type) type {
    return struct {
        ptr: ?*anyopaque,
        vtable: ?*const VTable,

        pub const VTable = struct {
            enabled: *const fn (?*anyopaque, Instrument.EnabledOptions) bool,
            observe: *const fn (?*anyopaque, T, attributes: ?[]const api.Attribute) void,
        };
    };
}

pub fn Counter(T: type) type {
    return struct {
        ptr: ?*anyopaque,
        vtable: ?*const VTable,

        pub const NULL = @This(){ .ptr = null, .vtable = null };

        pub const EnabledOptions = Instrument.EnabledOptions;
        pub const CreateOptions = struct {
            unit: ?[]const u8 = null,
            description: ?[]const u8 = null,
            advisory: ?Advisory = null,

            pub const Advisory = struct {
                attributes: ?[]const api.Attribute = null,
            };
        };

        pub const VTable = struct {
            enabled: *const fn (?*anyopaque, Instrument.EnabledOptions) bool,
            add: *const fn (?*anyopaque, T, attributes: ?[]const api.Attribute) void,
        };
    };
}

pub fn ObservableCounter(T: type) type {
    return struct {
        ptr: ?*anyopaque,
        vtable: ?*const VTable,

        pub const NULL = @This(){ .ptr = null, .vtable = null };

        pub const EnabledOptions = Instrument.EnabledOptions;
        pub const CreateOptions = struct {
            unit: ?[]const u8 = null,
            description: ?[]const u8 = null,
            advisory: ?Advisory = null,

            pub const Advisory = struct {
                attributes: ?[]const api.Attribute = null,
            };
        };

        pub const Callback = struct {
            ptr: ?*anyopaque,
            vtable: ?*const Callback.VTable,

            pub const VTable = struct {
                unregister: *const fn (?*anyopaque) void,
            };

            pub const Fn = *const fn (?*anyopaque, ObservableResult(T)) void;
        };

        pub const VTable = struct {
            enabled: *const fn (?*anyopaque, Instrument.EnabledOptions) bool,
            register_callback: *const fn (?*anyopaque, Callback.Fn, ?*anyopaque) Callback,
        };
    };
}

pub fn Histogram(T: type) type {
    return struct {
        ptr: ?*anyopaque,
        vtable: ?*const VTable,

        pub const NULL = @This(){ .ptr = null, .vtable = null };

        pub const EnabledOptions = Instrument.EnabledOptions;
        pub const CreateOptions = struct {
            unit: ?[]const u8 = null,
            description: ?[]const u8 = null,
            advisory: ?Advisory = null,

            pub const Advisory = struct {
                explicit_bucket_boundaries: ?[]const f64 = null,
                attributes: ?[]const api.Attribute = null,
            };
        };

        pub const VTable = struct {
            enabled: *const fn (?*anyopaque, Instrument.EnabledOptions) bool,
            record: *const fn (?*anyopaque, T, attributes: ?[]const api.Attribute) void,
        };
    };
}

pub fn Gauge(T: type) type {
    return struct {
        ptr: ?*anyopaque,
        vtable: ?*const VTable,

        pub const NULL = @This(){ .ptr = null, .vtable = null };

        pub const EnabledOptions = Instrument.EnabledOptions;
        pub const CreateOptions = struct {
            unit: ?[]const u8 = null,
            description: ?[]const u8 = null,
            advisory: ?Advisory = null,

            pub const Advisory = struct {
                attributes: ?[]const api.Attribute = null,
            };
        };

        pub const VTable = struct {
            enabled: *const fn (?*anyopaque, Instrument.EnabledOptions) bool,
            record: *const fn (?*anyopaque, T, attributes: ?[]const api.Attribute) void,
        };
    };
}

pub fn ObservableGauge(T: type) type {
    return struct {
        ptr: ?*anyopaque,
        vtable: ?*const VTable,

        pub const NULL = @This(){ .ptr = null, .vtable = null };

        pub const EnabledOptions = Instrument.EnabledOptions;
        pub const CreateOptions = struct {
            unit: ?[]const u8 = null,
            description: ?[]const u8 = null,
            advisory: ?Advisory = null,

            pub const Advisory = struct {
                attributes: ?[]const api.Attribute = null,
            };
        };

        pub const Callback = struct {
            ptr: ?*anyopaque,
            vtable: ?*const Callback.VTable,

            pub const VTable = struct {
                unregister: *const fn (?*anyopaque) void,
            };

            pub const Fn = *const fn (?*anyopaque, ObservableResult(T)) void;
        };

        pub const VTable = struct {
            enabled: *const fn (?*anyopaque, Instrument.EnabledOptions) bool,
            register_callback: *const fn (?*anyopaque, Callback.Fn, ?*anyopaque) Callback,
        };
    };
}

pub fn UpDownCounter(T: type) type {
    return struct {
        ptr: ?*anyopaque,
        vtable: ?*const VTable,

        pub const NULL = @This(){ .ptr = null, .vtable = null };

        pub const EnabledOptions = Instrument.EnabledOptions;
        pub const CreateOptions = struct {
            unit: ?[]const u8 = null,
            description: ?[]const u8 = null,
            advisory: ?Advisory = null,

            pub const Advisory = struct {
                attributes: ?[]const api.Attribute = null,
            };
        };

        pub const VTable = struct {
            enabled: *const fn (?*anyopaque, Instrument.EnabledOptions) bool,
            add: *const fn (?*anyopaque, T, attributes: ?[]const api.Attribute) void,
        };

        pub fn add(this: @This(), value: T, attributes: ?[]const api.Attribute) void {
            const vtable = this.vtable orelse return;
            return vtable.add(this.ptr, value, attributes);
        }
    };
}

pub fn ObservableUpDownCounter(T: type) type {
    return struct {
        ptr: ?*anyopaque,
        vtable: ?*const VTable,

        pub const NULL = @This(){ .ptr = null, .vtable = null };

        pub const EnabledOptions = Instrument.EnabledOptions;
        pub const CreateOptions = struct {
            unit: ?[]const u8 = null,
            description: ?[]const u8 = null,
            advisory: ?Advisory = null,

            pub const Advisory = struct {
                attributes: ?[]const api.Attribute = null,
            };
        };

        pub const Callback = struct {
            ptr: ?*anyopaque,
            vtable: ?*const Callback.VTable,

            pub const VTable = struct {
                unregister: *const fn (?*anyopaque) void,
            };

            pub const Fn = *const fn (?*anyopaque, ObservableResult(T)) void;
        };

        pub const VTable = struct {
            enabled: *const fn (?*anyopaque, Instrument.EnabledOptions) bool,
            register_callback: *const fn (?*anyopaque, Callback.Fn, ?*anyopaque) Callback,
        };
    };
}

pub fn voidMeterProvider(comptime scope: api.InstrumentationScope) Meter {
    _ = scope;
    return Meter{ .ptr = null, .vtable = null };
}

const api = @import("../api.zig");
