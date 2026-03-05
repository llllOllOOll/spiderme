const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const spider_dep = b.dependency("spider", .{
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true, // required for libpq
            .imports = &.{
                .{ .name = "spider", .module = spider_dep.module("spider") },
            },
        }),
    });

    // Link against system-wide libpq
    exe.root_module.linkSystemLibrary("pq", .{});

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}

// const std = @import("std");
//
// pub fn build(b: *std.Build) void {
//     const target = b.standardTargetOptions(.{});
//     const optimize = b.standardOptimizeOption(.{});
//
//     const mod = b.addModule("drivers", .{
//         .root_source_file = b.path("src/root.zig"),
//         .target = target,
//     });
//
//     const exe = b.addExecutable(.{
//         .name = "drivers",
//         .root_module = b.createModule(.{
//             .root_source_file = b.path("src/main.zig"),
//             .target = target,
//             .optimize = optimize,
//             .imports = &.{
//                 .{ .name = "drivers", .module = mod },
//             },
//         }),
//     });
//
//     b.installArtifact(exe);
//
//     const run_step = b.step("run", "Run the app");
//
//     const run_cmd = b.addRunArtifact(exe);
//     run_step.dependOn(&run_cmd.step);
//
//     run_cmd.step.dependOn(b.getInstallStep());
//
//     if (b.args) |args| {
//         run_cmd.addArgs(args);
//     }
//
//     const mod_tests = b.addTest(.{
//         .root_module = mod,
//     });
//
//     const run_mod_tests = b.addRunArtifact(mod_tests);
//
//     const exe_tests = b.addTest(.{
//         .root_module = exe.root_module,
//     });
//
//     const run_exe_tests = b.addRunArtifact(exe_tests);
//
//     const test_step = b.step("test", "Run tests");
//     test_step.dependOn(&run_mod_tests.step);
//     test_step.dependOn(&run_exe_tests.step);
// }
