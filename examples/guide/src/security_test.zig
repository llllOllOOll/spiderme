//! content/docs/security.md: what stands between the internet and a handler.
const std = @import("std");
const spider = @import("spider");
const run = @import("server.zig").run;

test "cross-site: a form on another site cannot post here; the app's own pages and other programs can" {
    const app = try spider.testing.start(run);

    // A browser says where a request comes from. Another site: refused
    // before any route is looked at.
    var forged = try app.request(.{ .method = "POST", .target = "/notes", .body = "", .headers = &.{ "Sec-Fetch-Site: cross-site", "Origin: https://evil.example" } });
    defer forged.deinit();
    try forged.expectStatus(403);

    // The app's own page.
    var own = try app.request(.{ .method = "POST", .target = "/notes", .body = "", .headers = &.{"Sec-Fetch-Site: same-origin"} });
    defer own.deinit();
    try own.expectStatus(201);

    // Not a browser (a script, another server): it carries nobody's
    // cookies, so there is nothing to forge.
    var program = try app.request(.{ .method = "POST", .target = "/notes", .body = "" });
    defer program.deinit();
    try program.expectStatus(201);
}

test "cross-site: a path the config exempts takes posts from anywhere" {
    const app = try spider.testing.start(run);
    var res = try app.request(.{ .method = "POST", .target = "/hooks/payments", .body = "", .headers = &.{ "Sec-Fetch-Site: cross-site", "Origin: https://pay.example" } });
    defer res.deinit();
    try res.expectStatus(200);
}

test "https: a request that came over plain HTTP is sent to the HTTPS address" {
    const app = try spider.testing.start(run);

    // The proxy says which one the visitor used.
    var plain = try app.with(&.{"X-Forwarded-Proto: http"}).get("/whoami?x=1");
    defer plain.deinit();
    try plain.expectRedirect("https://guide.example/whoami?x=1");

    var secure = try app.with(&.{"X-Forwarded-Proto: https"}).get("/whoami");
    defer secure.deinit();
    try secure.expectStatus(200);

    // A route that says `.allow_http` answers either way.
    var hook = try app.request(.{ .method = "POST", .target = "/hooks/payments", .body = "", .headers = &.{"X-Forwarded-Proto: http"} });
    defer hook.deinit();
    try hook.expectStatus(200);
}

test "the visitor's address: what the trusted proxy wrote, not what the visitor claims" {
    const app = try spider.testing.start(run);

    // The proxy appends the address it saw to whatever came in the header,
    // so the last entry is the one to believe: a visitor who sends
    // "X-Forwarded-For: 6.6.6.6" does not become 6.6.6.6.
    var res = try app.with(&.{"X-Forwarded-For: 6.6.6.6, 203.0.113.7"}).get("/whoami");
    defer res.deinit();
    try res.expectContains("\"ip\":\"203.0.113.7\"");
    try res.expectContains("\"peer\":\"127.0.0.1\"");
}

test "request id: the proxy's is kept, and comes back in the answer" {
    const app = try spider.testing.start(run);

    var given = try app.with(&.{"X-Request-Id: edge-7f3a"}).get("/whoami");
    defer given.deinit();
    try given.expectHeader("X-Request-Id", "edge-7f3a");
    try given.expectContains("\"request_id\":\"edge-7f3a\"");

    // Without one, Spider makes it up: 16 hex digits.
    var made = try app.get("/whoami");
    defer made.deinit();
    try std.testing.expectEqual(@as(usize, 16), made.header("X-Request-Id").?.len);
}
