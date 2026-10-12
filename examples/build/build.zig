const std = @import("std");
const spider_build = @import("spider");

// Nothing here is an app to deploy: `zig build test` is all there is.
// See README.md.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const test_step = b.step("test", "Run the examples");

    // The same app, built twice: templates in the binary, templates on disk.
    const embedded = app(b, "hello-embedded", spider(b, target, optimize, .embedded), target, optimize);
    const disk = app(b, "hello-disk", spider(b, target, optimize, .disk), target, optimize);

    // Templates in the binary: it answers from a directory with no templates.
    const embedded_elsewhere = b.addRunArtifact(embedded);
    embedded_elsewhere.setCwd(b.path("elsewhere"));
    embedded_elsewhere.expectStdOutEqual("200 <h1>Hello, build</h1>\n");
    embedded_elsewhere.expectStdErrMatch("Server listening");
    test_step.dependOn(&embedded_elsewhere.step);

    // Templates on disk: it answers where `views_dir` leads to the files...
    const disk_here = b.addRunArtifact(disk);
    disk_here.setCwd(b.path("."));
    disk_here.expectStdOutEqual("200 <h1>Hello, build</h1>\n");
    disk_here.expectStdErrMatch("templates are read from \"./src\" on every request");
    test_step.dependOn(&disk_here.step);

    // ...and has no page to give anywhere else.
    const disk_elsewhere = b.addRunArtifact(disk);
    disk_elsewhere.setCwd(b.path("elsewhere"));
    disk_elsewhere.expectStdOutEqual("500 Internal Server Error\n");
    disk_elsewhere.expectStdErrMatch("views_dir \"./src\" not found");
    test_step.dependOn(&disk_elsewhere.step);

    test_step.dependOn(checkTemplateList(b, embedded));

    const spider_mod = spider(b, target, optimize, .auto).module("spider");

    // A part that was asked for: the test compiles and runs.
    const ticket = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/ticket.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "spider", .module = spider_mod }},
    }) });
    test_step.dependOn(&b.addRunArtifact(ticket).step);

    // A part that was not: the file does not compile, and that is the test.
    const sheet = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/sheet.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "spider", .module = spider_mod }},
    }) });
    sheet.expect_errors = .{ .contains = "no module named 'spider_xlsx' available within module 'spider'" };
    test_step.dependOn(&sheet.step);
}

/// Spider, as this project asks for it.
fn spider(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    templates: spider_build.Templates,
) *std.Build.Dependency {
    return b.dependency("spider", .{
        .target = target,
        // Spider is compiled in the mode the app is: without this line it
        // stays in Debug in a release build.
        .optimize = optimize,
        // The optional parts this project uses. The rest stay out.
        .qrcode = true,
        // Where templates come from: .auto, .embedded or .disk.
        .templates = templates,
    });
}

/// The app in src/main.zig, on the Spider given.
fn app(
    b: *std.Build,
    name: []const u8,
    spider_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
) *std.Build.Step.Compile {
    const spider_mod = spider_dep.module("spider");
    spider_mod.addImport("spider_config", b.createModule(.{
        .root_source_file = b.path("spider.config.zig"),
        .imports = &.{.{ .name = "spider", .module = spider_mod }},
    }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "spider", .module = spider_mod }},
        }),
    });
    embedTemplates(b, spider_dep, exe);
    return exe;
}

/// Writes src/embedded_templates.zig, the list of every `.html` under
/// src/, before the app is compiled.
fn embedTemplates(b: *std.Build, spider_dep: *std.Build.Dependency, exe: *std.Build.Step.Compile) void {
    const gen = b.addRunArtifact(spider_dep.artifact("generate-templates"));
    gen.addArg("src/");
    gen.addArg("src/embedded_templates.zig");
    exe.step.dependOn(&gen.step);
}

/// What that file has for this project: one line, for its one template.
fn checkTemplateList(b: *std.Build, exe: *std.Build.Step.Compile) *std.Build.Step {
    const check = b.addCheckFile(b.path("src/embedded_templates.zig"), .{ .expected_matches = &.{
        "    hello_index: []const u8 = @embedFile(\"features/hello/views/index.html\"),",
    } });
    // After the app is compiled, so after the file was written.
    check.step.dependOn(&exe.step);
    return &check.step;
}
