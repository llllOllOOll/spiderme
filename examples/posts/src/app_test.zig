//! Calls every route of the app, the way a browser would.
//!
//! `spider.testing.start` runs the real server once for all the tests
//! here, on a free port; the database is a scratch one with the migrations
//! applied, so the four sample posts are there and db.sqlite is untouched.
const std = @import("std");
const spider = @import("spider");
const core = @import("core");
const main = @import("main.zig");
const db = spider.sqlite;

const scratch_db = ".zig-cache/posts-test.sqlite";

/// What main() does, on the scratch database.
fn run() !void {
    const gpa = std.heap.smp_allocator;
    var threaded: std.Io.Threaded = .init(gpa, .{});
    const io = threaded.io();

    std.Io.Dir.cwd().deleteFile(io, scratch_db) catch {};
    try db.init(gpa, io, .{ .path = scratch_db });
    try core.db.migrations.migrate(gpa);
    try main.serve(gpa, io);
}

/// Publishes a post as `writer` (a signed-in visitor) and gives back its
/// address, "/posts/5".
fn publish(writer: spider.testing.App, title: []const u8, body: []const u8) ![]const u8 {
    var res = try writer.postForm("/posts/create", .{ .title = title, .body = body });
    defer res.deinit();
    try res.expectStatus(303);
    return std.testing.allocator.dupe(u8, res.header("Location").?);
}

fn path(buf: []u8, post: []const u8, rest: []const u8) []const u8 {
    return std.fmt.bufPrint(buf, "{s}{s}", .{ post, rest }) catch unreachable;
}

// ── reading: for everyone ───────────────────────────────────────────────

test "GET / goes to the feed" {
    const app = try spider.testing.start(run);
    var res = try app.get("/");
    defer res.deinit();
    try res.expectRedirect("/posts");
}

test "GET /posts lists the posts, newest first" {
    const app = try spider.testing.start(run);
    var res = try app.get("/posts");
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectContains("Latest posts");

    const newest = std.mem.indexOf(u8, res.body, "Routes that read like a sentence").?;
    const oldest = std.mem.indexOf(u8, res.body, "Running Spider in a tiny container").?;
    try std.testing.expect(newest < oldest);
    try res.expectContains("2 hours ago");
    try res.expectContains("Last week");
}

test "GET /posts?q= searches titles and bodies" {
    const app = try spider.testing.start(run);

    var by_title = try app.get("/posts?q=container");
    defer by_title.deinit();
    try by_title.expectContains("Running Spider in a tiny container");
    try by_title.expectNotContains("My first week with Zig 0.17");

    var by_body = try app.get("/posts?q=ALLOCATORS");
    defer by_body.deinit();
    try by_body.expectContains("My first week with Zig 0.17");

    var none = try app.get("/posts?q=nothing+like+this");
    defer none.deinit();
    try none.expectStatus(200);
    try none.expectContains("No post mentions “nothing like this”.");
}

test "GET /posts/:id shows a post, its body rendered from Markdown" {
    const app = try spider.testing.start(run);
    var res = try app.get("/posts/4");
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectContains("Routes that read like a sentence");
    try res.expectContains("<h2>What I deleted</h2>");
    try res.expectContains("<code>/posts/:id</code>");
}

test "a missing post, a bad id and an unknown address get the 404 page" {
    const app = try spider.testing.start(run);
    for ([_][]const u8{ "/posts/9999", "/posts/abc", "/nowhere" }) |target| {
        var res = try app.get(target);
        defer res.deinit();
        try res.expectStatus(404);
        try res.expectContains("This page is not here");
    }
}

// ── writing: for who is signed in ───────────────────────────────────────
// `signUp` (below, with the tests of the login) creates an account and
// gives back its Cookie header; `app.with` sends it on every request.

test "writing needs a login: a visitor is sent to the sign-in page" {
    const app = try spider.testing.start(run);

    for ([_][]const u8{ "/posts/new", "/posts/4/edit", "/posts/4/delete" }) |target| {
        var res = try app.get(target);
        defer res.deinit();
        try res.expectRedirect("/auth/login");
    }

    var create = try app.postForm("/posts/create", .{ .title = "No session", .body = "x" });
    defer create.deinit();
    try create.expectRedirect("/auth/login");

    var delete = try app.request(.{ .method = "POST", .target = "/posts/4/delete" });
    defer delete.deinit();
    try delete.expectRedirect("/auth/login");

    // And nothing was written or removed.
    var feed = try app.get("/posts");
    defer feed.deinit();
    try feed.expectNotContains("No session");
    try feed.expectContains("Routes that read like a sentence");
}

test "GET /posts/new shows the form to who is signed in" {
    const app = try spider.testing.start(run);
    var buf: [1024]u8 = undefined;
    const writer = app.with(&.{try signUp(app, &buf, "Form Reader", "form@example.com")});

    var res = try writer.get("/posts/new");
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectContains("Publish post");
}

test "POST /posts/create says what is missing and keeps what was typed" {
    const app = try spider.testing.start(run);
    var buf: [1024]u8 = undefined;
    const writer = app.with(&.{try signUp(app, &buf, "Hasty Writer", "hasty@example.com")});

    var res = try writer.postForm("/posts/create", .{ .title = "Only a title", .body = "  " });
    defer res.deinit();
    try res.expectStatus(422);
    try res.expectContains("Write something in the body.");
    try res.expectNotContains("Give the post a title.");
    try res.expectContains("value=\"Only a title\"");
}

test "POST /posts/create saves the post under the name of who is signed in" {
    const app = try spider.testing.start(run);
    var buf: [1024]u8 = undefined;
    const writer = app.with(&.{try signUp(app, &buf, "Zé; da Silva", "ze@example.com")});

    // The form has no author field, and one sent anyway is ignored.
    var res = try writer.postForm("/posts/create", .{ .title = "Hello from the test", .body = "A **bold** start.", .author = "Someone Else" });
    defer res.deinit();
    try res.expectStatus(303);

    var post = try app.get(res.header("Location").?);
    defer post.deinit();
    try post.expectContains("Hello from the test");
    try post.expectContains("A <b>bold</b> start.");
    try post.expectContains("Zé; da Silva");
    try post.expectNotContains("Someone Else");
    try post.expectContains("Just now");
}

test "GET /posts/:id escapes what the author typed" {
    const app = try spider.testing.start(run);
    var cookie: [1024]u8 = undefined;
    const writer = app.with(&.{try signUp(app, &cookie, "Curious Writer", "curious@example.com")});
    const post = try publish(writer, "<b>Bold</b> claims", "Hi <script>alert(1)</script> and [x](javascript:alert)");
    defer std.testing.allocator.free(post);

    var res = try app.get(post);
    defer res.deinit();
    try res.expectContains("&lt;b&gt;Bold&lt;/b&gt; claims");
    try res.expectContains("&lt;script&gt;alert(1)&lt;/script&gt;");
    try res.expectNotContains("<script>");
    try res.expectNotContains("javascript:");
}

test "GET /posts/:id/edit and POST /posts/:id/update change a post" {
    const app = try spider.testing.start(run);
    var cookie: [1024]u8 = undefined;
    const writer = app.with(&.{try signUp(app, &cookie, "First Author", "first@example.com")});
    const post = try publish(writer, "Before the edit", "First version.");
    defer std.testing.allocator.free(post);
    var buf: [64]u8 = undefined;

    var form = try writer.get(path(&buf, post, "/edit"));
    defer form.deinit();
    try form.expectStatus(200);
    try form.expectContains("value=\"Before the edit\"");
    try form.expectContains("Save changes");

    var invalid = try writer.postForm(path(&buf, post, "/update"), .{ .title = "x", .body = "" });
    defer invalid.deinit();
    try invalid.expectStatus(422);
    try invalid.expectContains("Write something in the body.");

    // Someone else edits it: the post keeps its author.
    var other_cookie: [1024]u8 = undefined;
    const editor = app.with(&.{try signUp(app, &other_cookie, "Second Editor", "second@example.com")});
    var saved = try editor.postForm(path(&buf, post, "/update"), .{ .title = "After the edit", .body = "Second version." });
    defer saved.deinit();
    try saved.expectRedirect(post);

    var page = try app.get(post);
    defer page.deinit();
    try page.expectContains("After the edit");
    try page.expectContains("Second version.");
    try page.expectNotContains("Before the edit");
    try page.expectContains("First Author");
    try page.expectNotContains("Second Editor");

    var missing = try writer.postForm("/posts/9999/update", .{ .title = "x", .body = "x" });
    defer missing.deinit();
    try missing.expectStatus(404);
}

test "GET /posts/:id/delete asks first, POST /posts/:id/delete removes the post" {
    const app = try spider.testing.start(run);
    var cookie: [1024]u8 = undefined;
    const writer = app.with(&.{try signUp(app, &cookie, "Tidy Writer", "tidy@example.com")});
    const post = try publish(writer, "Soon gone", "Not for long.");
    defer std.testing.allocator.free(post);
    var buf: [64]u8 = undefined;

    var ask = try writer.get(path(&buf, post, "/delete"));
    defer ask.deinit();
    try ask.expectStatus(200);
    try ask.expectContains("Delete this post?");
    try ask.expectContains("Soon gone");

    var still_there = try app.get(post);
    defer still_there.deinit();
    try still_there.expectStatus(200);

    var gone = try writer.postForm(path(&buf, post, "/delete"), .{});
    defer gone.deinit();
    try gone.expectRedirect("/posts");

    var after = try app.get(post);
    defer after.deinit();
    try after.expectStatus(404);

    var missing = try writer.postForm("/posts/9999/delete", .{});
    defer missing.deinit();
    try missing.expectStatus(404);
}

test "GET /posts/export.csv downloads every post as a file" {
    const app = try spider.testing.start(run);
    var cookie: [1024]u8 = undefined;
    const writer = app.with(&.{try signUp(app, &cookie, "Test Writer", "csv@example.com")});
    const post = try publish(writer, "Commas, and \"quotes\"", "x");
    defer std.testing.allocator.free(post);

    var res = try app.get("/posts/export.csv");
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectHeader("Content-Type", "text/csv; charset=utf-8");
    try res.expectHeader("Content-Disposition", "attachment; filename=\"posts.csv\"");
    try res.expectContains("id,title,author\n");
    try res.expectContains(",\"Routes that read like a sentence\",\"Ana Ribeiro\"\n");
    try res.expectContains(",\"Commas, and \"\"quotes\"\"\",\"Test Writer\"\n");
}

// ── the JSON API ────────────────────────────────────────────────────────

const key = "X-Api-Key: dev-key";

test "the API needs its key, and answers errors in JSON" {
    const app = try spider.testing.start(run);

    var none = try app.get("/api/posts");
    defer none.deinit();
    try none.expectStatus(401);
    try none.expectHeader("Content-Type", "application/json");

    var wrong = try app.request(.{ .target = "/api/posts", .headers = &.{"X-Api-Key: guess"} });
    defer wrong.deinit();
    try wrong.expectStatus(401);

    var missing = try app.request(.{ .target = "/api/posts/9999", .headers = &.{key} });
    defer missing.deinit();
    try missing.expectStatus(404);
    try missing.expectHeader("Content-Type", "application/json");
    try missing.expectContains("\"error\":");
}

test "GET /api/posts lists, searches and limits; its answers are not cached" {
    const app = try spider.testing.start(run);

    var all = try app.request(.{ .target = "/api/posts", .headers = &.{key} });
    defer all.deinit();
    try all.expectStatus(200);
    try all.expectHeader("Cache-Control", "no-store");
    try all.expectContains("\"title\":\"Routes that read like a sentence\"");
    try all.expectContains("\"author\":\"Tom Becker\"");

    var found = try app.request(.{ .target = "/api/posts?q=container", .headers = &.{key} });
    defer found.deinit();
    try found.expectContains("Running Spider in a tiny container");
    try found.expectNotContains("My first week with Zig 0.17");

    var none = try app.request(.{ .target = "/api/posts?limit=0", .headers = &.{key} });
    defer none.deinit();
    try none.expectContains("{\"posts\":[]}");

    var bad = try app.request(.{ .target = "/api/posts?limit=many", .headers = &.{key} });
    defer bad.deinit();
    try bad.expectStatus(400);
    try bad.expectContains("limit must be a whole number");
}

test "GET /api/posts/:id shows one post; an id that is not a number is a 400" {
    const app = try spider.testing.start(run);

    var one = try app.request(.{ .target = "/api/posts/4", .headers = &.{key} });
    defer one.deinit();
    try one.expectStatus(200);
    try one.expectContains("\"id\":4,\"title\":\"Routes that read like a sentence\"");

    var bad = try app.request(.{ .target = "/api/posts/four", .headers = &.{key} });
    defer bad.deinit();
    try bad.expectStatus(400);
}

test "POST /api/posts saves a post sent as JSON" {
    const app = try spider.testing.start(run);
    const json = &.{ key, "Content-Type: application/json" };

    var saved = try app.request(.{
        .method = "POST",
        .target = "/api/posts",
        .headers = json,
        .body = "{\"title\":\"From the API\",\"body\":\"Sent as JSON.\",\"author\":\"A program\"}",
    });
    defer saved.deinit();
    try saved.expectStatus(201);
    const location = saved.header("Location").?;
    try std.testing.expect(std.mem.startsWith(u8, location, "/api/posts/"));

    var back = try app.request(.{ .target = location, .headers = &.{key} });
    defer back.deinit();
    try back.expectContains("\"title\":\"From the API\"");

    var empty = try app.request(.{ .method = "POST", .target = "/api/posts", .headers = json, .body = "{\"title\":\"Only a title\"}" });
    defer empty.deinit();
    try empty.expectStatus(422);
    try empty.expectContains("\"body\":\"Write something in the body.\"");

    var not_json = try app.request(.{ .method = "POST", .target = "/api/posts", .headers = json, .body = "title=x" });
    defer not_json.deinit();
    try not_json.expectStatus(400);
}

// ── login (spider g auth) ───────────────────────────────────────────────
// The tests share one database: each one uses an email of its own.

/// Creates an account and gives back the Cookie header of its session.
fn signUp(app: spider.testing.App, buf: []u8, name: []const u8, email: []const u8) ![]const u8 {
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

test "auth: the sign-in form remembers the email of the last sign-in" {
    const app = try spider.testing.start(run);

    var res = try app.postForm("/auth/register", .{ .name = "Flávia", .email = "flavia+posts@example.com", .password = "a good password" });
    defer res.deinit();
    try res.expectRedirect("/");
    // Encoded: a "+" and an "@" are not safe in a cookie as they are.
    try std.testing.expectEqualStrings("flavia%2Bposts%40example.com", res.cookie("last_email").?);

    // Signed out, back on the same browser: the email is already typed.
    var form = try app.request(.{ .target = "/auth/login", .headers = &.{"Cookie: last_email=flavia%2Bposts%40example.com"} });
    defer form.deinit();
    try form.expectContains("value=\"flavia+posts@example.com\"");
}
