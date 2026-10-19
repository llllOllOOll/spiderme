//! The app with its module, running: the module's route and job are there
//! beside the app's own routes.
const std = @import("std");
const spider = @import("spider");
const main = @import("main.zig");

fn run() !void {
    try main.serve();
}

/// The header the monitor sends: the token build.zig gives the tests.
fn bearer(buf: []u8) ![]const u8 {
    return std.fmt.bufPrint(buf, "Authorization: Bearer {s}", .{spider.env.get("HEARTBEAT_TOKEN").?});
}

test "the app's own routes answer beside the module's" {
    const app = try spider.testing.start(run);
    var res = try app.get("/");
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectContains("An app with a module");
}

test "the module's route answers the monitor that sends the token" {
    const app = try spider.testing.start(run);
    var buf: [128]u8 = undefined;
    var res = try app.with(&.{try bearer(&buf)}).get("/heartbeat");
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectContains("\"beats\":");
}

test "without the token, the module's route answers 401" {
    const app = try spider.testing.start(run);
    var res = try app.get("/heartbeat");
    defer res.deinit();
    try res.expectStatus(401);
}

test "the module's job runs: the beats go up" {
    const app = try spider.testing.start(run);
    var buf: [128]u8 = undefined;
    const monitor = app.with(&.{try bearer(&buf)});

    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();
    const Status = struct { beats: u64, up_seconds: i64 };
    // The first beat comes one interval after listen(): wait up to three.
    var tries: usize = 0;
    while (tries < 30) : (tries += 1) {
        var res = try monitor.get("/heartbeat");
        defer res.deinit();
        const parsed = try std.json.parseFromSlice(Status, std.testing.allocator, res.body, .{});
        defer parsed.deinit();
        if (parsed.value.beats > 0) return;
        try std.Io.Clock.Duration.sleep(.{ .clock = .awake, .raw = .fromMilliseconds(100) }, threaded.io());
    }
    return error.TheJobNeverRan;
}
