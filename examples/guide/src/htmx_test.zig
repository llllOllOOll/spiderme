//! content/docs/htmx.md: what the server tells htmx.
const std = @import("std");
const spider = @import("spider");
const run = @import("server.zig").run;

const htmx = &.{"HX-Request: true"};

test "htmx: the same address gives the page to a browser and the part to htmx" {
    const app = try spider.testing.start(run);

    var page = try app.get("/tasks");
    defer page.deinit();
    try page.expectContains("<h1>Tasks</h1>");

    var part = try app.with(htmx).get("/tasks");
    defer part.deinit();
    try part.expectNotContains("<h1>");
    try part.expectContains("<ul id=\"tasks\">");

    // Two answers at one address: a cache has to keep them apart.
    try page.expectHeader("Vary", "HX-Request");
    try part.expectHeader("Vary", "HX-Request");
}

test "htmx: an answer says where it goes and what the page should announce" {
    const app = try spider.testing.start(run);
    var res = try app.with(htmx).request(.{ .method = "POST", .target = "/tasks", .body = "" });
    defer res.deinit();
    try res.expectStatus(201);
    try res.expectHeader("HX-Retarget", "#tasks");
    try res.expectHeader("HX-Reswap", "beforeend");
    try res.expectHeader("HX-Trigger", "{\"notice\":{\"message\":\"Task added\",\"type\":\"success\"}}");
    try std.testing.expectEqualStrings("<li>Call the supplier</li>", res.body);
}

test "htmx: an error keeps the page as it is and raises a notice" {
    const app = try spider.testing.start(run);
    var res = try app.with(htmx).request(.{ .method = "POST", .target = "/tasks/7/archive", .body = "" });
    defer res.deinit();
    try res.expectStatus(403);
    // Nothing is swapped: what the visitor was looking at stays.
    try res.expectHeader("HX-Reswap", "none");
    try std.testing.expect(std.mem.startsWith(u8, res.header("HX-Trigger").?, "{\"spider:toast\":{\"message\":"));
    // "warning" for what the caller did (4xx), "error" for what broke (5xx).
    try std.testing.expect(std.mem.indexOf(u8, res.header("HX-Trigger").?, "\"type\":\"warning\"") != null);
}
