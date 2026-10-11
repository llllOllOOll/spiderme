//! A server whose visitors sign in at Keycloak. It is apart from
//! src/server.zig because it needs a Keycloak to start: see login-test.sh.
const std = @import("std");
const spider = @import("spider");

var keycloak: spider.keycloak.Keycloak = undefined;

pub fn run() !void {
    // (`io` is the one main() received; this package has no main.)
    const io = std.Options.debug_io;

    // An app reads these from the environment:
    // `spider.keycloak.KeycloakConfig.fromEnv()`.
    keycloak = try spider.keycloak.Keycloak.init(std.heap.smp_allocator, io, .{
        .base_url = "http://127.0.0.1:8189",
        .realm = "guide",
        .client_id = "guide-app",
        .client_secret = "only-for-the-tests",
        // The address of the callback route below, as the realm knows it.
        .redirect_uri = "http://127.0.0.1:3000/auth/callback",
        .after_callback_path = "/me",
    });
    defer keycloak.deinit();

    var server = spider.app(.{});
    defer server.deinit();

    try server
        .use(spider.logger)
        // Reads the token of each request and tells the routes who is there.
        .use(keycloak.middleware())
        .get("/auth/login", keycloak.loginHandler(), .{ .public = true })
        .get("/auth/callback", keycloak.callbackHandler(), .{ .public = true })
        .get("/auth/refresh", keycloak.refreshHandler(), .{ .public = true })
        .post("/auth/logout", logout, .{ .public = true })
        .get("/", home, .{ .public = true })
        .get("/me", me, .{ .authenticated = true })
        .get("/drafts", drafts, .{ .roles = &.{"editor"} })
        .listen(.{});
}

/// Signing out of the app is forgetting its two cookies.
fn logout(c: *spider.Ctx) !spider.Response {
    return c.redirectWith("/", .{ .headers = &.{
        .{ "Set-Cookie", try c.deleteCookie("__session", .{}) },
        .{ "Set-Cookie", try c.deleteCookie("__refresh", .{}) },
    } });
}

fn home(c: *spider.Ctx) !spider.Response {
    return c.text("Anyone may read this.", .{});
}

/// Who the token says is there.
fn me(c: *spider.Ctx) !spider.Response {
    return c.json(.{
        .id = c.userId() orelse "",
        .name = c.params.get("_auth_name") orelse "",
        .email = c.params.get("_auth_email") orelse "",
        .editor = c.hasRole("editor"),
    }, .{});
}

fn drafts(c: *spider.Ctx) !spider.Response {
    return c.text("Two drafts.", .{});
}
