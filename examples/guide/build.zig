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
    // The templates (every .html under src/): c.view checks each view's
    // data against its template when the tests compile, as in an app.
    @import("spider").addTemplates(b, spider_dep, "src");
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
    const test_step = b.step("test", "Run the examples");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    // A misspelled component: the file does not compile, and that is the
    // test. Each line of the expected error ends with the text given.
    const typo = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/typo.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "spider", .module = spider_mod }},
    }) });
    typo.expect_errors = .{ .contains = "src/features/shop/views/typo.html:2: view \"shop/typo\": <ProdctCard> is not a component: no template file ProdctCard.html (or prodct_card.html) and no <ProdctCard>...</ProdctCard> defined in this file" };
    test_step.dependOn(&typo.step);

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
