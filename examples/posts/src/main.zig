const std = @import("std");
const spider = @import("spider");
const features = @import("features");
const db = spider.sqlite;

pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;

pub fn main(init: std.process.Init) !void {
    try db.init(init.arena.allocator(), init.io, .{});
    defer db.deinit();
    try serve();
}

/// Builds the server and listens. The tests call it too (src/app_test.zig),
/// on a database of their own.
pub fn serve() !void {
    var server = spider.app(.{});
    defer server.deinit();

    // Routes live with their feature (src/features/<name>/routes.zig);
    // mountFeatures registers every feature listed in src/features/mod.zig.
    // `spider routes` prints what got registered.
    try server
        .use(spider.logger)
        .mountFeatures(features)
        .onError(onError)
        // Port and host come from spider.config.zig; the PORT variable
        // (the environment or .env) replaces the port.
        .listen(.{});
}

/// A missing post or page gets the 404 page; any other error gets Spider's
/// own answer.
fn onError(c: *spider.Ctx, err: anyerror) anyerror!spider.Response {
    if (err == error.NotFound) {
        return c.view("not-found", .{ .title = "Page not found" }, .{ .status = .not_found });
    }
    return fallback(c, err);
}

const fallback = spider.errorHandler(.{});

// Routes in routes.zig with declared access, ui-* classes, icons from the
// active sets, features registered: `spider check` prints the same report.
test "the app follows Spider's conventions" {
    try @import("spider").testing.expectConventions();
}

test {
    _ = @import("app_test.zig");
}

test "every file with tests is part of this test binary" {
    try @import("spider").testing.expectAllTestsDiscovered(@import("test_manifest"));
}
