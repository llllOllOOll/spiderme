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

/// What main() does to serve.
fn run() !void {
    const gpa = std.heap.smp_allocator;
    var threaded: std.Io.Threaded = .init(gpa, .{});
    const io = threaded.io();

    try main.serve(gpa, io);
}

test "the board page answers with the canvas and the QR code" {
    const app = try spider.testing.start(run);

    var res = try app.get("/");
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectContains("<canvas id=\"board\"");
    try res.expectContains("Paint with us");
    try res.expectContains("<svg xmlns=\"http://www.w3.org/2000/svg\"");
}
