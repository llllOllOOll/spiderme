//! Tells an uptime monitor that the app's background work is alive.
//!
//! A Spider module: the app mounts it with `server.mountModules(.{heartbeat})`.
//! A job beats once a second, and `GET /heartbeat` answers how many beats
//! there have been since the server started, to whoever sends the token of
//! `HEARTBEAT_TOKEN`. A monitor that sees the number stop going up knows the
//! jobs stopped, even while the pages still answer.

const std = @import("std");
const spider = @import("spider");

/// What the module is, for Spider: checked when the app compiles.
pub const spider_module = spider.module(.{
    .name = "heartbeat",
    .version = "0.1.0",
    // The Spider versions this module was tested with.
    .spider = ">=0.11.0 <0.12.0",
    // Spider refuses to start the server while one of these is not set.
    .env = .{ .required = .{"HEARTBEAT_TOKEN"} },
});

/// The shortest token accepted.
pub const min_token_len = 16;

/// Runs before the server listens. Spider has already checked that
/// HEARTBEAT_TOKEN is set; this checks what only the module knows.
pub fn check(c: *spider.Check) !void {
    const token = c.env("HEARTBEAT_TOKEN") orelse return;
    if (token.len < min_token_len)
        c.fail("HEARTBEAT_TOKEN must be at least {d} characters (it has {d})", .{ min_token_len, token.len });
}

// What the module keeps while the server runs.
var started_s: ?i64 = null;
var beats: std.atomic.Value(u64) = .init(0);

/// Runs once, after every check passed and before the first request.
pub fn boot(b: spider.Boot) !void {
    started_s = std.Io.Clock.real.now(b.io).toSeconds();
    beats.store(0, .monotonic);
}

/// Runs from `server.deinit()`, after the jobs stopped: a server started
/// again in the same process begins from nothing.
pub fn shutdown(_: spider.Boot) void {
    started_s = null;
    beats.store(0, .monotonic);
}

/// How often the job beats, in milliseconds.
pub const every_ms = 1000;

/// Started by `listen()`; the first beat comes one interval after it.
pub const jobs = .{spider.every(every_ms, beat)};

fn beat(_: *spider.Hub) void {
    _ = beats.fetchAdd(1, .monotonic);
}

/// Mounted by `mountModules`, like a feature's routes.
pub const routes = struct {
    pub fn build() spider.Group {
        var g = spider.Group.init("/heartbeat");
        // Public to the app's login: the token is the module's own.
        _ = g.get("", status, .{ .public = true, .quiet_log = true });
        return g;
    }
};

fn status(c: *spider.Ctx) !spider.Response {
    const token = spider.env.get("HEARTBEAT_TOKEN") orelse "";
    if (!authorized(c.header("Authorization"), token)) return error.Unauthorized;
    const now_s = std.Io.Clock.real.now(c.io()).toSeconds();
    return c.json(.{
        .beats = beats.load(.monotonic),
        .up_seconds = now_s - (started_s orelse now_s),
    }, .{});
}

/// Whether the header is `Bearer <token>`, compared in constant time.
pub fn authorized(header: ?[]const u8, token: []const u8) bool {
    const value = header orelse return false;
    const prefix = "Bearer ";
    if (token.len == 0 or !std.mem.startsWith(u8, value, prefix)) return false;
    const given = value[prefix.len..];
    if (given.len != token.len) return false;
    var diff: u8 = 0;
    for (given, token) |a, b| diff |= a ^ b;
    return diff == 0;
}

/// Whether boot() ran and shutdown() has not.
pub fn running() bool {
    return started_s != null;
}

test "authorized: the bearer token, and nothing else" {
    const token = "0123456789abcdef";
    try std.testing.expect(authorized("Bearer 0123456789abcdef", token));
    try std.testing.expect(!authorized("Bearer 0123456789abcdeX", token));
    try std.testing.expect(!authorized("0123456789abcdef", token));
    try std.testing.expect(!authorized(null, token));
    try std.testing.expect(!authorized("Bearer ", ""));
}

test "through Spider: ready with a token, and deinit runs shutdown" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();

    // build.zig gives this test run a HEARTBEAT_TOKEN long enough.
    var server = spider.app(.{});
    _ = server.mountModules(.{@This()});
    try std.testing.expect(server.check(arena.allocator(), threaded.io()).ok());

    // listen() would boot it; here the test does.
    try boot(.{ .allocator = std.testing.allocator, .io = threaded.io() });
    try std.testing.expect(running());
    server.deinit();
    try std.testing.expect(!running());
}
