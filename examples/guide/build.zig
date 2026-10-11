const std = @import("std");

// Builds nothing to run: `zig build test` is all there is. See README.md.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const spider_dep = b.dependency("spider", .{
        .target = target,
        .optimize = optimize,
        // The parts of Spider an app asks for by name.
        .xlsx = true,
        .qrcode = true,
        .r2 = true,
    });
    const spider_mod = spider_dep.module("spider");
    spider_mod.addImport("spider_config", b.createModule(.{
        .root_source_file = b.path("spider.config.zig"),
        .imports = &.{.{ .name = "spider", .module = spider_mod }},
    }));

    const tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "spider", .module = spider_mod }},
    }) });
    b.step("test", "Run the examples").dependOn(&b.addRunArtifact(tests).step);

    // Signing in at Keycloak needs a Keycloak: a step of its own, run by
    // login-test.sh, which starts one for the occasion.
    const login_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("login/tests.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "spider", .module = spider_mod }},
    }) });
    b.step("test-login", "Run the login examples (needs login/docker-compose.yml up)").dependOn(&b.addRunArtifact(login_tests).step);
}
