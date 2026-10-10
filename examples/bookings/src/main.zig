const std = @import("std");
const spider = @import("spider");
const core = @import("core");
const features = @import("features");
const db = spider.pg;

pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    try db.init(allocator, io, .{});
    defer db.deinit();

    // Applies the migrations that have not run yet, the ones `spider migrate`
    // applies: a new database, or a new container, is ready when the server
    // starts. The list is src/core/db/migrations.zig.
    try core.db.migrations.migrate(allocator);

    try serve(allocator, io);
}

/// Builds the server and listens. main() calls it, and so do the tests in
/// src/app_test.zig.
pub fn serve(allocator: std.mem.Allocator, io: std.Io) !void {
    // What the server needs before it starts goes here (`spider g auth
    // --provider=keycloak` puts the Keycloak provider in this spot).
    _ = allocator;
    _ = io;

    var server = spider.app(.{});
    defer server.deinit();

    // Routes live with their feature (src/features/<name>/routes.zig);
    // mountFeatures registers every feature listed in src/features/mod.zig.
    // `spider routes` prints what got registered.
    server
        .use(spider.logger)
        // Reads the login cookie (or a bearer token) and tells the routes
        // who is there; a route that is not `.public` needs a login.
        .use(spider.session.middleware())
        // A comment line down every open stream each 30 seconds: proxies
        // close a connection that says nothing.
        .sseHeartbeat(null)
        .mountFeatures(features)
        .onError(onError)
        // Port and host come from spider.config.zig; the PORT variable
        // (the environment or .env) replaces the port.
        .listen(.{}) catch |err| return err;
}

/// Where every error a handler or a middleware returns ends up: a missing
/// room, booking or page gets the 404 page, something the visitor may not
/// do the 403 page, nobody signed in the sign-in page; anything else gets
/// Spider's own answer.
fn onError(c: *spider.Ctx, err: anyerror) anyerror!spider.Response {
    if (err == error.NotFound) {
        return c.view("not-found", .{ .title = "Not found" }, .{ .status = .not_found });
    }
    return fallback(c, err);
}

const fallback = spider.errorHandler(.{
    .unauthorized_redirect = "/auth/login",
    .forbidden_view = "not-allowed",
});

// Routes in routes.zig with declared access, ui-* classes, icons from the
// active sets, features registered: `spider check` prints the same report.
test "the app follows Spider's conventions" {
    try @import("spider").testing.expectConventions();
}

// Requests against the running app: src/app_test.zig.
test {
    _ = @import("app_test.zig");
    _ = @import("data_test.zig");
    _ = @import("pages_test.zig");
}

test "every file with tests is part of this test binary" {
    try @import("spider").testing.expectAllTestsDiscovered(@import("test_manifest"));
}
