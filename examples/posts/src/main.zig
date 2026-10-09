const std = @import("std");
const spider = @import("spider");
const core = @import("core");
const features = @import("features");
const db = spider.sqlite;

pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    try db.init(allocator, init.io, .{});
    defer db.deinit();

    // Applies the migrations that have not run yet, the ones `spider migrate`
    // applies: a new database, or a new container, is ready when the server
    // starts. The list is src/core/db/migrations.zig.
    try core.db.migrations.migrate(allocator);

    try serve(allocator, init.io);
}

/// Builds the server and listens. main() calls it, and so do the tests in
/// src/app_test.zig.
pub fn serve(allocator: std.mem.Allocator, io: std.Io) !void {
    // What the server needs before it starts goes here. Posts needs
    // nothing yet.
    _ = allocator;
    _ = io;

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

/// Where every error a handler or a middleware returns ends up. The API
/// answers in JSON; a missing post or page gets the 404 page; anything
/// else gets Spider's own answer.
fn onError(c: *spider.Ctx, err: anyerror) anyerror!spider.Response {
    if (std.mem.startsWith(u8, c.getPath(), "/api/")) return api_errors(c, err);
    if (err == error.NotFound) {
        return c.view("not-found", .{ .title = "Page not found" }, .{ .status = .not_found });
    }
    return fallback(c, err);
}

const fallback = spider.errorHandler(.{});
const api_errors = spider.errorHandler(.{ .always_json = true });

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
