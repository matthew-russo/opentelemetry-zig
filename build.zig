const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const api_lib = b.addStaticLibrary(.{
        .name = "opentelemetry-zig-api",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/api/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const sdk_lib = b.addStaticLibrary(.{
        .name = "opentelemetry-zig-sdk",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/sdk/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create a zig module for our library
    const api_module = b.addModule("opentelemetry-api", .{
        .root_source_file = b.path("src/api/root.zig"),
    });

    const sdk_module = b.addModule("opentelemetry-sdk", .{
        .root_source_file = b.path("src/sdk/root.zig"),
    });

    const oasis = b.dependency("oasis", .{
        .target = target,
        .optimize = optimize,
    });

    sdk_module.addImport("oasis", oasis.module("oasis"));
    sdk_module.addImport("opentelemetry-api", api_module);

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(api_lib);
    b.installArtifact(sdk_lib);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const api_lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/api/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const sdk_lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/sdk/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    sdk_lib_unit_tests.root_module.addImport("oasis", oasis.module("oasis"));
    sdk_lib_unit_tests.root_module.addImport("opentelemetry-api", api_lib.root_module);

    const run_api_lib_unit_tests = b.addRunArtifact(api_lib_unit_tests);
    const run_sdk_lib_unit_tests = b.addRunArtifact(sdk_lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_api_lib_unit_tests.step);
    test_step.dependOn(&run_sdk_lib_unit_tests.step);

    // examples

    const example_logs_exe = b.addExecutable(.{
        .name = "example_logs_exe",
        .root_source_file = b.path("examples/logs.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_logs_exe.root_module.addImport("opentelemetry-api", api_lib.root_module);
    example_logs_exe.root_module.addImport("opentelemetry-sdk", sdk_lib.root_module);
    b.installArtifact(example_logs_exe);

    const example_metrics_exe = b.addExecutable(.{
        .name = "example_metrics_exe",
        .root_source_file = b.path("examples/metrics.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_metrics_exe.root_module.addImport("opentelemetry-api", api_lib.root_module);
    example_metrics_exe.root_module.addImport("opentelemetry-sdk", sdk_lib.root_module);
    b.installArtifact(example_metrics_exe);

    const example_traces_exe = b.addExecutable(.{
        .name = "example_traces_exe",
        .root_source_file = b.path("examples/traces.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_traces_exe.root_module.addImport("opentelemetry-api", api_lib.root_module);
    example_traces_exe.root_module.addImport("opentelemetry-sdk", sdk_lib.root_module);
    b.installArtifact(example_traces_exe);

    const run_logs_example_exe = b.addRunArtifact(example_logs_exe);
    const run_metrics_example_exe = b.addRunArtifact(example_metrics_exe);
    const run_traces_example_exe = b.addRunArtifact(example_traces_exe);

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_logs_example_exe.step);
    run_step.dependOn(&run_metrics_example_exe.step);
    run_step.dependOn(&run_traces_example_exe.step);
}
