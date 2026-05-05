const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const spider_dep = b.dependency("spider", .{ .target = target });
    const spider_mod = spider_dep.module("spider");

    const exe = b.addExecutable(.{
        .name = "spiderme",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "spider", .module = spider_mod },
            },
        }),
    });

    const config_exists = blk: {
        std.Io.Dir.cwd().access(b.graph.io, "spider.config.zig", .{}) catch break :blk false;
        break :blk true;
    };
    if (config_exists) {
        spider_mod.addAnonymousImport("spider_config", .{
            .root_source_file = b.path("spider.config.zig"),
        });
    }

    const gen = b.addRunArtifact(spider_dep.artifact("generate-templates"));
    gen.addArg("src/");
    gen.addArg("src/embedded_templates.zig");
    exe.step.dependOn(&gen.step);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
