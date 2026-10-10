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
pub fn running() !spider.testing.App {
    return spider.testing.start(run);
}

test "the home page answers" {
    const app = try running();

    var res = try app.get("/");
    defer res.deinit();
    try res.expectStatus(200);
}

test "the database answers" {
    _ = try running();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();

    const Row = struct { db: []const u8 };
    const row = (try spider.pg.queryOne(Row, arena.allocator(), "SELECT current_database()::text AS db", .{})).?;
    try std.testing.expectEqualStrings("bookings_test", row.db);
}

// ── login (spider g auth) ───────────────────────────────────────────────
// The tests share one database: each one uses an email of its own.

/// Creates an account and gives back the Cookie header of its session.
pub fn signUp(app: spider.testing.App, buf: []u8, name: []const u8, email: []const u8) ![]const u8 {
    var res = try app.postForm("/auth/register", .{ .name = name, .email = email, .password = "a good password" });
    defer res.deinit();
    try res.expectRedirect("/");
    return std.fmt.bufPrint(buf, "Cookie: session={s}", .{res.cookie("session").?});
}

test "auth: a page that needs a login sends a visitor to the sign-in page" {
    const app = try spider.testing.start(run);

    var res = try app.get("/auth/account");
    defer res.deinit();
    try res.expectRedirect("/auth/login");

    var form = try app.get("/auth/login");
    defer form.deinit();
    try form.expectStatus(200);
    try form.expectContains("Sign in");
}

test "auth: creating an account signs in" {
    const app = try spider.testing.start(run);
    var buf: [1024]u8 = undefined;
    const cookie = try signUp(app, &buf, "Ana Ribeiro", "Ana@Example.com");

    var account = try app.request(.{ .target = "/auth/account", .headers = &.{cookie} });
    defer account.deinit();
    try account.expectStatus(200);
    try account.expectContains("Ana Ribeiro");
    try account.expectContains("ana@example.com");
}

test "auth: a registration with a problem says what it is" {
    const app = try spider.testing.start(run);

    var short = try app.postForm("/auth/register", .{ .name = "Bia", .email = "bia@example.com", .password = "short" });
    defer short.deinit();
    try short.expectStatus(422);
    try short.expectContains("Use a password of at least 8 characters.");
    try std.testing.expect(short.cookie("session") == null);

    var buf: [1024]u8 = undefined;
    _ = try signUp(app, &buf, "Caio", "caio@example.com");
    var twice = try app.postForm("/auth/register", .{ .name = "Caio", .email = "caio@example.com", .password = "another password" });
    defer twice.deinit();
    try twice.expectStatus(422);
    try twice.expectContains("That email already has an account.");
}

test "auth: signing in needs the right password" {
    const app = try spider.testing.start(run);
    var buf: [1024]u8 = undefined;
    _ = try signUp(app, &buf, "Duda", "duda@example.com");

    var wrong = try app.postForm("/auth/login", .{ .email = "duda@example.com", .password = "not the password" });
    defer wrong.deinit();
    try wrong.expectStatus(422);
    try wrong.expectContains("Wrong email or password.");
    try std.testing.expect(wrong.cookie("session") == null);

    var nobody = try app.postForm("/auth/login", .{ .email = "nobody@example.com", .password = "a good password" });
    defer nobody.deinit();
    try nobody.expectStatus(422);
    try nobody.expectContains("Wrong email or password.");

    var right = try app.postForm("/auth/login", .{ .email = " DUDA@example.com ", .password = "a good password" });
    defer right.deinit();
    try right.expectRedirect("/");
    try std.testing.expect(right.cookie("session").?.len > 0);
}

test "auth: signing out ends the session" {
    const app = try spider.testing.start(run);
    var buf: [1024]u8 = undefined;
    const cookie = try signUp(app, &buf, "Eva", "eva@example.com");

    var out = try app.request(.{ .method = "POST", .target = "/auth/logout", .headers = &.{cookie} });
    defer out.deinit();
    try out.expectRedirect("/auth/login");
    try std.testing.expectEqualStrings("", out.cookie("session").?);
}
