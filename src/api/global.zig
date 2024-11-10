const std = @import("std");

const logs = @import("logs.zig");
const metrics = @import("metrics.zig");
const traces = @import("traces.zig");

// ==========================================================
//
//                           Logs
//
// ==========================================================

// A global LoggerProvider, interacted with through the apis:
// - setLoggerProvider
// - unsetLoggerProvider
// - getLoggerProvider
//
// This global variable is not thread safe
var global_logger_provider: ?logs.LoggerProvider = null;

/// Set the default LoggerProvider to the provided implementation
///
/// # Concurrency
/// This api is not thread-safe. Its intended to be called once during application
/// initialization
pub fn setLoggerProvider(logger_provider: logs.LoggerProvider) void {
    global_logger_provider = logger_provider;
}

/// Unset the default LoggerProvider
///
/// # Concurrency
/// This api is not thread-safe.
pub fn unsetLoggerProvider() void {
    global_logger_provider = null;
}

/// Get the default LoggerProvider, if any.
///
/// # Concurrency
/// This api is not thread-safe.
pub fn getLoggerProvider() *?logs.LoggerProvider {
    return &global_logger_provider;
}

// ==========================================================
//
//                          Metrics
//
// ==========================================================

// A global MeterProvider, interacted with through the apis:
// - setMeterProvider
// - unsetMeterProvider
// - getMeterProvider
//
// This global variable is not thread safe
var global_meter_provider: ?metrics.MeterProvider = null;

/// Set the default MeterProvider to the provided implementation
///
/// # Concurrency
/// This api is not thread-safe. Its intended to be called once during application
/// initialization
pub fn setMeterProvider(meter_provider: metrics.MeterProvider) void {
    global_meter_provider = meter_provider;
}

/// Unset the default MeterProvider
///
/// # Concurrency
/// This api is not thread-safe.
pub fn unsetMeterProvider() void {
    global_meter_provider = null;
}

/// Get the default MeterProvider, if any.
///
/// # Concurrency
/// This api is not thread-safe.
pub fn getMeterProvider() *?metrics.MeterProvider {
    return &global_meter_provider;
}

// ==========================================================
//
//                          Traces
//
// ==========================================================

// A global TracerProvider, interacted with through the apis:
// - setTraceProvider
// - unsetTraceProvider
// - getTraceProvider
//
// This global variable is not thread safe
var global_tracer_provider: ?traces.TracerProvider = null;

/// Set the default TracerProvider to the provided implementation
///
/// # Concurrency
/// This api is not thread-safe. Its intended to be called once during application
/// initialization
pub fn setTracerProvider(tracer_provider: traces.TracerProvider) void {
    global_tracer_provider = tracer_provider;
}

/// Unset the default TracerProvider
///
/// # Concurrency
/// This api is not thread-safe.
pub fn unsetTracerProvider() void {
    global_tracer_provider = null;
}

/// Get the default TracerProvider, if any.
///
/// # Concurrency
/// This api is not thread-safe.
pub fn getTracerProvider() *?traces.TracerProvider {
    return &global_tracer_provider;
}
