//! A whole app in one file: one page, made from a template.
const std = @import("std");
const spider = @import("spider");

/// The templates of the app, for a build that keeps them in the binary.
/// The build writes `embedded_templates.zig` from the `.html` files.
pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;

fn hello(c: *spider.Ctx) !spider.Response {
    return c.view("hello/index", .{ .name = "build" }, .{});
}

fn run() !void {
    var server = spider.app(.{});
    defer server.deinit();
    try server.get("/", hello, .{ .public = true }).listen(.{});
}

/// Not a server to leave running: it asks itself for the page once and
/// prints what came back, so that the build can check the answer.
pub fn main() !void {
    const app = try spider.testing.start(run);
    var res = try app.get("/");
    defer res.deinit();

    var buffer: [256]u8 = undefined;
    var out = std.Io.File.stdout().writer(std.Options.debug_io, &buffer);
    try out.interface.print("{d} {s}\n", .{ res.status, std.mem.trim(u8, res.body, "\n") });
    try out.interface.flush();
}
