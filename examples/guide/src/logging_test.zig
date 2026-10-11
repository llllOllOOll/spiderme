//! content/docs/logging.md: the lines an app writes besides the request log.
const std = @import("std");
const spider = @import("spider");

/// In an app this line goes in src/main.zig, next to `pub fn main`: std.log
/// reads it from there.
pub const std_options: std.Options = .{ .logFn = spider.logFn };

test "spider.logFn is a log function std.log takes" {
    try std.testing.expect(std_options.logFn == spider.logFn);
}

test "a stream gets its log line when it ends" {
    const app = try spider.testing.start(@import("server.zig").run);
    var res = try app.get("/ticks");
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectContains("event: tick");
}
