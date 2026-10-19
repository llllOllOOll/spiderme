//! The heartbeat module as a package of its own, as it would be in a
//! repository of its own: an app adds it and gives it the app's `spider`;
//! `zig build test` here runs its tests on the Spider of build.zig.zon, or
//! on a Spider checkout: `zig build test --fork=<path to it>`.

const std = @import("std");

pub fn build(b: *std.Build) void {
    // An app that depends on this package only takes src/heartbeat.zig and
    // gives it the app's own spider. A second Spider here would meet the
    // app's in one build ("file exists in modules 'spider' and
    // 'spider0'"): what follows is this package's own build, its tests.
    if (!b.isRoot()) return;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // Lazy: only fetched here, never by an app that depends on the package.
    const spider_dep = b.lazyDependency("spider", .{ .target = target, .optimize = optimize }) orelse return;

    const tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/heartbeat.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "spider", .module = spider_dep.module("spider") }},
    }) });
    const run = b.addRunArtifact(tests);
    run.setEnvironmentVariable("HEARTBEAT_TOKEN", "a-token-of-the-module-tests");
    b.step("test", "The module's own tests").dependOn(&run.step);
}
