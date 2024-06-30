const std = @import("std");
const resource = @import("../resource.zig");

pub const LogTypeList = std.ArrayList(LogType);
pub const LogTypeMap = std.StringHashMap(LogType);

pub const LogType = union(enum) {
    string: []const u8,
    boolean: bool,
    int: i64,
    // double precision (IEEE 754-1985)
    float: f64,
    bytes: []const u8,
    list: LogTypeList,
    map: LogTypeMap,
};

pub const Severity = enum(u8) {
    Trace = 1,
    Trace2 = 2,
    Trace3 = 3,
    Trace4 = 4,
    Debug = 5,
    Debug2 = 6,
    Debug3 = 7,
    Debug4 = 8,
    Info = 9,
    Info2 = 10,
    Info3 = 11,
    Info4 = 12,
    Warn = 13,
    Warn2 = 14,
    Warn3 = 15,
    Warn4 = 16,
    Error = 17,
    Error2 = 18,
    Error3 = 19,
    Error4 = 20,
    Fatal = 21,
    Fatal2 = 22,
    Fatal3 = 23,
    Fatal4 = 24,
};

pub const InstrumentationScope = struct {
    name: []const u8,
    version: []const u8,
};

pub const LogRecord = struct {
    // Time when the event occurred measured by the origin clock, i.e. the time
    // at the source. This field is optional, it may be missing if the source
    // timestamp is unknown.
    //
    // field is encoded as nanoseconds since epoch
    timestamp: u64,
    // Time when the event was observed by the collection system. For events that
    // originate in OpenTelemetry (e.g. using OpenTelemetry Logging SDK) this
    // timestamp is typically set at the generation time and is equal to Timestamp.
    // For events originating externally and collected by OpenTelemetry (e.g. using
    // Collector) this is the time when OpenTelemetry’s code observed the event
    // measured by the clock of the OpenTelemetry code.
    //
    // This field SHOULD be set once the event is observed by OpenTelemetry.
    //
    // Use Timestamp if it is present, otherwise use ObservedTimestamp.
    //
    // field is encoded as nanoseconds since epoch
    observed_timestamp: u64,
    // Request trace id as defined in W3C Trace Context. Can be set for logs that
    // are part of request processing and have an assigned trace id. This field
    // is optional.
    trace_id: []const u8,
    // Can be set for logs that are part of a particular processing span. If
    // SpanId is present TraceId SHOULD be also present. This field is optional.
    span_id: []const u8,
    // Trace flag as defined in W3C Trace Context specification. At the time of
    // writing the specification defines one flag - the SAMPLED flag. This field
    // is optional.
    trace_flags: u8,
    // This is the original string representation of the severity as it is known
    // at the source. If this field is missing and SeverityNumber is present then
    // the short name that corresponds to the SeverityNumber may be used as a
    // substitution. This field is optional.
    severity_text: []const u8,
    // Numerical value of the severity, normalized to values described in this
    // document. This field is optional.
    //
    // SeverityNumber range | Range name | Meaning
    // ---------------------+------------+------------------------------------
    // 1-4                  | TRACE      | A fine-grained debugging event. Typically
    //                      |            |   disabled in default configurations.
    // ---------------------+------------+------------------------------------
    // 5-8                  | DEBUG      | A debugging event.
    // ---------------------+------------+------------------------------------
    // 9-12                 | INFO       | An informational event. Indicates that
    //                      |            |   an event happened.
    // ---------------------+------------+------------------------------------
    // 13-16                | WARN       | A warning event. Not an error but is
    //                      |            |   likely more important than an informational
    //                      |            |   event.
    // ---------------------+------------+------------------------------------
    // 17-20                | ERROR      | An error event. Something went wrong.
    // ---------------------+------------+------------------------------------
    // 21-24                | FATAL      | A fatal error such as application or
    //                      |            |   system crash.
    // ---------------------+------------+------------------------------------
    severity_number: Severity,
    body: LogType,
    resource: resource.Resource,
    instrumentation_scope: InstrumentationScope,
    attributes: LogTypeMap,
};
