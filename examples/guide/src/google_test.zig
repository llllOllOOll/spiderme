//! content/docs/login-providers.md: "Sign in with Google".
const std = @import("std");
const spider = @import("spider");
const server = @import("server.zig");
const Stub = @import("stub.zig").Stub;

test "google: the visitor goes to Google with a state this browser keeps" {
    const app = try spider.testing.start(server.run);
    var res = try app.get("/auth/google");
    defer res.deinit();
    try res.expectStatus(302);

    const to = res.header("Location").?;
    try std.testing.expect(std.mem.startsWith(u8, to, "https://accounts.google.com/o/oauth2/v2/auth?"));
    try std.testing.expect(std.mem.indexOf(u8, to, "client_id=1234-abcd.apps.googleusercontent.com") != null);
    // The same value goes in the address and in a cookie.
    const state = res.cookie(spider.google.state_cookie).?;
    try std.testing.expect(std.mem.indexOf(u8, to, state) != null);
}

test "google: back with a code, the app asks Google who it is" {
    const app = try spider.testing.start(server.run);

    // Google, played by two servers of the test: one trades the code for a
    // token, the other gives the profile for the token.
    var token = try Stub.listen("200 OK", "{\"access_token\":\"ya29.token\"}");
    var userinfo = try Stub.listen("200 OK", "{\"id\":\"108204\",\"email\":\"ana@gmail.example\",\"name\":\"Ana Ribeiro\",\"picture\":\"\"}");
    const t1 = try std.Thread.spawn(.{}, Stub.serveOne, .{&token});
    const t2 = try std.Thread.spawn(.{}, Stub.serveOne, .{&userinfo});
    var buf1: [64]u8 = undefined;
    var buf2: [64]u8 = undefined;
    const before = server.google;
    defer server.google = before;
    server.google.token_endpoint = try std.fmt.bufPrint(&buf1, "http://127.0.0.1:{d}/token", .{token.port});
    server.google.userinfo_endpoint = try std.fmt.bufPrint(&buf2, "http://127.0.0.1:{d}/userinfo", .{userinfo.port});

    // The visitor starts at the app...
    var start = try app.get("/auth/google");
    defer start.deinit();
    var cookie_buf: [128]u8 = undefined;
    var target_buf: [160]u8 = undefined;
    const state = start.cookie(spider.google.state_cookie).?;
    const cookie = try std.fmt.bufPrint(&cookie_buf, "Cookie: {s}={s}", .{ spider.google.state_cookie, state });

    // ...and Google sends them back with the same state and a code.
    var back = try app.with(&.{cookie}).get(try std.fmt.bufPrint(&target_buf, "/auth/google/callback?state={s}&code=4/0AbCdEf", .{state}));
    defer back.deinit();
    t1.join();
    t2.join();

    try back.expectStatus(200);
    try back.expectContains("\"google_id\":\"108204\"");
    try back.expectContains("\"email\":\"ana@gmail.example\"");
    // The code and the client's secret went to Google, from the server.
    try std.testing.expect(token.got("code=4%2F0AbCdEf") or token.got("code=4/0AbCdEf"));
    try std.testing.expect(token.got("client_secret=only-for-the-tests"));
    try std.testing.expect(userinfo.got("Authorization: Bearer ya29.token"));
}

test "google: a callback this browser did not ask for is refused before Google is asked anything" {
    const app = try spider.testing.start(server.run);
    var res = try app.get("/auth/google/callback?state=made-up&code=4/0AbCdEf");
    defer res.deinit();
    try res.expectStatus(400);
}
