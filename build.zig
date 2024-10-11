const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a zig module for our library
    const api_module = b.addModule("api", .{
        .root_source_file = b.path("src/api.zig"),
    });

    const sdk_module = b.addModule("sdk", .{
        .root_source_file = b.path("src/sdk.zig"),
        .imports = &.{
            .{ .name = "api", .module = api_module },
        },
    });

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const api_lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/api.zig"),
        .target = target,
        .optimize = optimize,
    });
    const sdk_lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/sdk.zig"),
        .target = target,
        .optimize = optimize,
    });
    sdk_lib_unit_tests.root_module.addImport("api", api_module);

    const run_api_lib_unit_tests = b.addRunArtifact(api_lib_unit_tests);
    const run_sdk_lib_unit_tests = b.addRunArtifact(sdk_lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_api_lib_unit_tests.step);
    test_step.dependOn(&run_sdk_lib_unit_tests.step);

    // examples

    const example_trace_dice_exe = b.addExecutable(.{
        .name = "opentelemetry_trace_dice_example",
        .root_source_file = b.path("examples/trace/dice.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_trace_dice_exe.root_module.addImport("opentelemetry-sdk", sdk_module);
    b.installArtifact(example_trace_dice_exe);

    const example_metrics_allocations_exe = b.addExecutable(.{
        .name = "opentelemetry_example_metrics_allocations",
        .root_source_file = b.path("examples/metrics/allocations.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_metrics_allocations_exe.root_module.addImport("opentelemetry-sdk", sdk_module);
    b.installArtifact(example_metrics_allocations_exe);
}
