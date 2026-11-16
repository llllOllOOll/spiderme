const std = @import("std");

// An app with two modules: heartbeat (heartbeat/, a package of its own) and
// notify (from the spider-modules repository). `zig build test` runs every
// test of the example, the module's own included. See README.md.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const spider_dep = b.dependency("spider", .{
        .target = target,
        .optimize = optimize,
        // notify keeps its data in PostgreSQL: it needs spider.pg.
        .pg = true,
    });
    const spider_mod = spider_dep.module("spider");
    spider_mod.addImport("spider_config", b.createModule(.{
        .root_source_file = b.path("spider.config.zig"),
        .imports = &.{.{ .name = "spider", .module = spider_mod }},
    }));

    const heartbeat_mod = heartbeatModule(b, spider_mod, target);
    const notify_mod = notifyModule(b, spider_mod, target);

    const exe = b.addExecutable(.{
        .name = "modules-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "spider", .module = spider_mod },
                .{ .name = "heartbeat", .module = heartbeat_mod },
                .{ .name = "spider_notify", .module = notify_mod },
            },
        }),
    });
    b.installArtifact(exe);
    b.step("run", "Run the app").dependOn(&b.addRunArtifact(exe).step);

    const test_step = b.step("test", "Run the examples");

    // The app's tests, with the token the module requires.
    const app_tests = b.addRunArtifact(b.addTest(.{ .root_module = exe.root_module }));
    app_tests.setEnvironmentVariable("HEARTBEAT_TOKEN", "a-token-of-the-app-tests");
    test_step.dependOn(&app_tests.step);

    // The same module, with the token missing and with one too short: the
    // server must refuse to start, and say why.
    test_step.dependOn(notReady(b, "src/token_missing_test.zig", "", spider_mod, heartbeat_mod, target, optimize));
    test_step.dependOn(notReady(b, "src/token_short_test.zig", "short", spider_mod, heartbeat_mod, target, optimize));

    // What Spider refuses at compile time: each file must fail to build,
    // with that message.
    const refused = [_][2][]const u8{
        .{ "src/compile_errors/wrong_spider.zig", "spider.module(\"old_widget\"): supports Spider >=0.15.0 <0.16.0, but this is Spider 0.14.0-dev" },
        .{ "src/compile_errors/boot_signature.zig", "mountModules: module \"late\": boot must be `pub fn boot(b: spider.Boot) !void`" },
        .{ "src/compile_errors/requires_missing.zig", "mountModules: module \"billing\" requires \"audit\", which is not mounted: add it to the same mountModules call" },
        .{ "src/compile_errors/migrations_order.zig", "spider.module(\"audit\"): migration \"0001_init\" comes after \"0002_actor\": list migrations in the order they run, without repeats" },
    };
    for (refused) |case| {
        const t = b.addTest(.{ .root_module = b.createModule(.{
            .root_source_file = b.path(case[0]),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "spider", .module = spider_mod }},
        }) });
        t.expect_errors = .{ .contains = case[1] };
        test_step.dependOn(&t.step);
    }

    // The modules' migrations on a real PostgreSQL: not part of `test`,
    // ./test-db.sh starts a database for the run.
    const db_tests = b.addRunArtifact(b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/db_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "spider", .module = spider_mod },
            .{ .name = "spider_notify", .module = notify_mod },
        },
    }) }));
    db_tests.has_side_effects = true;
    b.step("test-db", "The modules' migrations (needs ./test-db.sh)").dependOn(&db_tests.step);

    // The module's own tests, in its own package, on its own Spider.
    const module_tests = b.addSystemCommand(&.{ b.graph.zig_exe, "build", "test" });
    module_tests.setCwd(b.path("heartbeat"));
    module_tests.has_side_effects = true;
    test_step.dependOn(&module_tests.step);
}

/// The heartbeat module, given the app's own spider. Its package has no
/// Spider of its own: there is one Spider in the build, the app's.
fn heartbeatModule(b: *std.Build, spider_mod: *std.Build.Module, target: std.Build.ResolvedTarget) *std.Build.Module {
    const dep = b.dependency("heartbeat", .{});
    return b.createModule(.{
        .root_source_file = dep.path("src/heartbeat.zig"),
        .target = target,
        .imports = &.{.{ .name = "spider", .module = spider_mod }},
    });
}

/// notify, from the spider-modules package, given the app's own spider.
fn notifyModule(b: *std.Build, spider_mod: *std.Build.Module, target: std.Build.ResolvedTarget) *std.Build.Module {
    const modules_dep = b.dependency("spider_modules", .{});
    return b.createModule(.{
        .root_source_file = modules_dep.path("notify/src/notify.zig"),
        .target = target,
        .imports = &.{.{ .name = "spider", .module = spider_mod }},
    });
}

/// A test file run with HEARTBEAT_TOKEN set to `token`.
fn notReady(
    b: *std.Build,
    path: []const u8,
    token: []const u8,
    spider_mod: *std.Build.Module,
    heartbeat_mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
) *std.Build.Step {
    const t = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path(path),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "spider", .module = spider_mod },
            .{ .name = "heartbeat", .module = heartbeat_mod },
        },
    }) });
    const run = b.addRunArtifact(t);
    run.setEnvironmentVariable("HEARTBEAT_TOKEN", token);
    return &run.step;
}
