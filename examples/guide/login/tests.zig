//! content/docs/login-providers.md: signing in at Keycloak, end to end.
//! Needs the Keycloak of login/docker-compose.yml: run ../login-test.sh.
const std = @import("std");
const spider = @import("spider");
const run = @import("server.zig").run;

/// One request to Keycloak, as the visitor's browser makes it: `cookies`
/// goes in, and the whole answer (head and body) comes back.
fn browser(arena: std.mem.Allocator, method: []const u8, url: []const u8, cookies: []const u8, form: []const u8) ![]const u8 {
    const io = std.testing.io;
    const origin = "http://127.0.0.1:8189";
    const target = url[origin.len..];
    const address = try std.Io.net.IpAddress.parse("127.0.0.1", 8189);
    var stream = try address.connect(io, .{ .mode = .stream });
    defer stream.close(io);
    var write_buf: [4096]u8 = undefined;
    var writer = stream.writer(io, &write_buf);
    try writer.interface.print("{s} {s} HTTP/1.1\r\nHost: 127.0.0.1:8189\r\nConnection: close\r\nCookie: {s}\r\n" ++
        "Content-Type: application/x-www-form-urlencoded\r\nContent-Length: {d}\r\n\r\n{s}", .{ method, target, cookies, form.len, form });
    try writer.interface.flush();
    var read_buf: [4096]u8 = undefined;
    var reader = stream.reader(io, &read_buf);
    return reader.interface.allocRemaining(arena, .limited(1024 * 1024));
}

/// The value of a header of `answer`, or of every one with that name
/// joined as a Cookie line when `name` is "Set-Cookie".
fn header(arena: std.mem.Allocator, answer: []const u8, name: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    const head = answer[0 .. std.mem.indexOf(u8, answer, "\r\n\r\n") orelse answer.len];
    var lines = std.mem.splitSequence(u8, head, "\r\n");
    while (lines.next()) |line| {
        if (line.len <= name.len or !std.ascii.eqlIgnoreCase(line[0..name.len], name) or line[name.len] != ':') continue;
        const value = std.mem.trim(u8, line[name.len + 1 ..], " ");
        if (!std.ascii.eqlIgnoreCase(name, "Set-Cookie")) return value;
        if (out.items.len > 0) try out.appendSlice(arena, "; ");
        try out.appendSlice(arena, value[0 .. std.mem.indexOfScalar(u8, value, ';') orelse value.len]);
    }
    return out.items;
}

/// Signs `username` in: the app sends the visitor to Keycloak, the visitor
/// types the password there, Keycloak sends them back with a code, and the
/// app trades the code for a session. Gives back the app's cookies.
fn signIn(arena: std.mem.Allocator, app: spider.testing.App, username: []const u8) ![]const u8 {
    // 1. The app's login route: off to Keycloak, with a `state` the app
    //    will recognize on the way back (it keeps a copy in a cookie).
    var login = try app.get("/auth/login");
    defer login.deinit();
    try login.expectStatus(302);
    const at_keycloak = try arena.dupe(u8, login.header("Location").?);
    try std.testing.expect(std.mem.startsWith(u8, at_keycloak, "http://127.0.0.1:8189/realms/guide/protocol/openid-connect/auth?"));
    const state_cookie = try std.fmt.allocPrint(arena, "Cookie: __oauth_state={s}", .{login.cookie("__oauth_state").?});

    // 2. Keycloak's own page, with the form.
    const page = try browser(arena, "GET", at_keycloak, "", "");
    const action_at = (std.mem.indexOf(u8, page, "action=\"") orelse return error.NoLoginForm) + "action=\"".len;
    const action_raw = page[action_at..std.mem.indexOfScalarPos(u8, page, action_at, '"').?];
    const action = try std.mem.replaceOwned(u8, arena, action_raw, "&amp;", "&");

    // 3. The visitor types the password, at Keycloak. The app never sees it.
    const form = try std.fmt.allocPrint(arena, "username={s}&password=a+good+password", .{username});
    const sent_back = try browser(arena, "POST", action, try header(arena, page, "Set-Cookie"), form);
    const callback = try header(arena, sent_back, "Location");
    try std.testing.expect(std.mem.startsWith(u8, callback, "http://127.0.0.1:3000/auth/callback?"));

    // 4. Back at the app, with a code: the app trades it for tokens and
    //    sets its cookies.
    var back = try app.with(&.{state_cookie}).get(callback["http://127.0.0.1:3000".len..]);
    defer back.deinit();
    try back.expectRedirect("/me");
    return std.fmt.allocPrint(arena, "Cookie: __session={s}; __refresh={s}", .{ back.cookie("__session").?, back.cookie("__refresh").? });
}

test "login: a visitor is sent to sign in, and comes back as themselves" {
    const app = try spider.testing.start(run);
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // Not signed in: a public page answers, any other sends to the login.
    var open = try app.get("/");
    defer open.deinit();
    try open.expectStatus(200);
    var closed = try app.get("/me");
    defer closed.deinit();
    try closed.expectRedirect("/auth/login");

    const ana = app.with(&.{try signIn(arena, app, "ana")});
    var me = try ana.get("/me");
    defer me.deinit();
    try me.expectStatus(200);
    try me.expectContains("\"name\":\"Ana Ribeiro\"");
    try me.expectContains("\"email\":\"ana@guide.example\"");
    try me.expectContains("\"editor\":true");
}

test "login: the roles given in Keycloak are the roles the routes check" {
    const app = try spider.testing.start(run);
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // Ana is an editor in the realm; Bo is not.
    var ana = try app.with(&.{try signIn(arena, app, "ana")}).get("/drafts");
    defer ana.deinit();
    try ana.expectStatus(200);

    var bo = try app.with(&.{try signIn(arena, app, "bo")}).get("/drafts");
    defer bo.deinit();
    try bo.expectStatus(403);
}

test "login: a callback nobody asked for is refused" {
    const app = try spider.testing.start(run);
    // A link someone made by hand: no cookie of this browser matches its state.
    var res = try app.get("/auth/callback?state=made-up&code=made-up");
    defer res.deinit();
    try res.expectRedirect("/auth/login");
}

test "login: a program sends its token in a header, and a bad one is refused" {
    const app = try spider.testing.start(run);
    var res = try app.with(&.{"Authorization: Bearer not-a-token"}).get("/me");
    defer res.deinit();
    try res.expectStatus(401);
}

test "login: signing out forgets the app's cookies" {
    const app = try spider.testing.start(run);
    var res = try app.request(.{ .method = "POST", .target = "/auth/logout", .body = "" });
    defer res.deinit();
    try res.expectRedirect("/");
    // Both come back empty and already expired.
    try std.testing.expectEqualStrings("", res.cookie("__session").?);
    try std.testing.expectEqualStrings("", res.cookie("__refresh").?);
}
