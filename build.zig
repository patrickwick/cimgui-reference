const std = @import("std");

const USE_LLVM = false;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "imgui_zig",
        .root_module = exe_mod,
        .use_llvm = USE_LLVM,
    });
    exe.linkLibC();
    exe.linkLibCpp();

    exe.linkSystemLibrary("gl");
    exe.linkSystemLibrary("x11");

    exe.addLibraryPath(.{ .cwd_relative = "dependencies/cimgui/backend_test/example_glfw_opengl3/build" });
    exe.linkSystemLibrary("cimgui");

    exe.addLibraryPath(.{ .cwd_relative = "dependencies/glfw3/build/src" });
    exe.linkSystemLibrary("glfw3");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
        .use_llvm = USE_LLVM,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
