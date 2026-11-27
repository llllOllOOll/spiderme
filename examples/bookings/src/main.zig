const std = @import("std");
const spider = @import("spider");
const core = @import("core");
const features = @import("features");
const db = spider.pg;

/// The migrations: every file of src/core/db/migrations/, built into the
/// binary (build.zig: spider.addMigrations).
const migrations = @import("migrations").all;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    try db.init(allocator, io, .{});
    defer db.deinit();

    // Applies the migrations that have not run yet: a new database, or a new
    // container, is ready when the server starts. `spider migrate`
    // (SPIDER_MIGRATE=1) only migrates.
    const applied = try migrate(allocator);
    if (spider.migrating()) {
        std.log.info("{d} migration(s) applied", .{applied});
        return;
    }

    try serve(allocator, io);
}

/// Applies the migrations that have not run yet, in order, each in its own
/// transaction with its row in schema_migrations, under a lock: several
/// copies of the app starting at once apply each one once. Returns how many
/// ran. A migration edited after it ran stops it (error.MigrationChanged):
/// add a new one instead. main() calls it, and so can the tests, on a test
/// database.
pub fn migrate(allocator: std.mem.Allocator) !usize {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var migrator = spider.app(.{});
    defer migrator.deinit();
    return migrator.migrations(migrations).migrate(arena.allocator());
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
/// Spider's own answer. The two pages are rendered here, not by
/// `errorHandler`, because they go inside the layout, and the layout reads
/// `nav` and `is_admin`: `c.view` checks that every view gives them.
fn onError(c: *spider.Ctx, err: anyerror) anyerror!spider.Response {
    if (err == error.NotFound) {
        return c.view("not-found", .{ .title = "Not found", .nav = "", .is_admin = c.hasRole("admin") }, .{ .status = .not_found });
    }
    if (err == error.Forbidden and !c.isHtmx() and !c.wantsJson()) {
        return c.view("not-allowed", .{ .title = "Not allowed", .nav = "", .is_admin = c.hasRole("admin") }, .{ .status = .forbidden });
    }
    return fallback(c, err);
}

const fallback = spider.errorHandler(.{
    .unauthorized_redirect = "/auth/login",
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
    _ = @import("migrations_test.zig");
}

test "every file with tests is part of this test binary" {
    try @import("spider").testing.expectAllTestsDiscovered(@import("test_manifest"));
}
