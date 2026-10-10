//! Requests against the app itself, in `zig build test`.
//!
//! `spider.testing.start` runs the real server once for all the tests of
//! the project, on a free port: middlewares, routes, templates and the
//! error handler all take part. Each test asks for the app and sends it
//! requests:
//!
//!     var res = try app.get("/posts");
//!     var res = try app.postForm("/posts/create", .{ .name = "A post" });
//!     var res = try app.request(.{ .method = "DELETE", .target = "/posts/1" });
//!
//! and checks the answer: res.status, res.body, res.header("Location"),
//! res.cookie("session"), res.expectStatus(200), res.expectContains("..."),
//! res.expectRedirect("/posts"). A redirect is not followed.
const std = @import("std");
const spider = @import("spider");
const main = @import("main.zig");

/// What main() does to serve, on the database the tests are given.
fn run() !void {
    const gpa = std.heap.smp_allocator;
    var threaded: std.Io.Threaded = .init(gpa, .{});
    const io = threaded.io();

    // The tests write to the database, so it is never the development one.
    // `./test.sh` starts a PostgreSQL that lives for one run and points the
    // PG_* variables at it; the tables are made here, as main() makes them.
    try spider.pg.init(gpa, io, .{ .database = "bookings_test" });
    try @import("core").db.migrations.migrate(gpa);

    try main.serve(gpa, io);
}

/// The running app, started once for every test of the project. The tests
/// of the data (src/data_test.zig) ask for it too: it is what connects to
/// the database and makes the tables.
pub fn app() !spider.testing.App {
    return spider.testing.start(run);
}

test "the home page answers" {
    const running = try app();

    var res = try running.get("/");
    defer res.deinit();
    try res.expectStatus(200);
}

test "the database answers" {
    _ = try app();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();

    const Row = struct { db: []const u8 };
    const row = (try spider.pg.queryOne(Row, arena.allocator(), "SELECT current_database()::text AS db", .{})).?;
    try std.testing.expectEqualStrings("bookings_test", row.db);
}
