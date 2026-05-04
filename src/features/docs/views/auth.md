-- doc

# Authentication

Spider provides a complete authentication system with JWT, cookies, and Google OAuth integration.

## JWT Authentication

Sign and verify JSON Web Tokens with built-in functions:

### Sign a JWT

```zig
const spider = @import("spider");
const auth = spider.auth;

pub fn login(c: *spider.Ctx) !spider.Response {
    const claims = .{
        .sub = "user123",        // user ID
        .email = "user@example.com",
        .name = "Alice",
        .exp = std.time.timestamp() + 86400,    // 1 day expiration
    };
    const token = try auth.jwtSign(c.arena, claims, "my-secret-key");
    
    const cookie = try auth.cookieSet(c.arena, token);
    return c.redirect("/dashboard").withCookie("session", cookie, .{});
}
```

### Verify a JWT

```zig
const Claims = struct {
    sub: []const u8,
    email: []const u8,
    name: []const u8,
    exp: i64,
};

pub fn profile(c: *spider.Ctx) !spider.Response {
    const token = c.cookie("session") orelse 
        return c.redirect("/login");
    
    const claims = auth.jwtVerify(Claims, c.arena, token, "my-secret-key") catch 
        return c.redirect("/login");
    
    return c.json(claims, .{});
}
```

## Auth Middleware

Protect routes with authentication middleware:

```zig
var gAuth = spider.auth.Auth.init(.{
    .secret = spider.env.getOr("JWT_SECRET", "changeme"),
    .public_paths = &.{ "/login", "/auth/*" },
    .redirect_to = "/login",
    .secure_cookie = false,  // true in production
});

server.group("/dashboard", &.{gAuth.asFn()}, dashRoutes);
```

The middleware injects into `c.params`:
- `_user_id` — JWT `sub` field as string
- `_user_email` — JWT `email` field
- `_user_name` — JWT `name` field

## Cookie Management

```zig
// Set cookie
const cookie = try spider.auth.cookieSet(c.arena, token);

// Clear cookie (logout)
const cleared = try spider.auth.cookieClear(c.arena);

// Use in response
return c.redirect("/").withCookie("session", cleared, .{});
```

## Google OAuth

```zig
const config = spider.google.GoogleConfig{
    .client_id = spider.env.getOr("GOOGLE_CLIENT_ID", ""),
    .client_secret = spider.env.getOr("GOOGLE_CLIENT_SECRET", ""),
    .redirect_uri = spider.env.getOr("GOOGLE_REDIRECT_URI", ""),
};

fn loginHandler(c: *spider.Ctx) !spider.Response {
    const url = try spider.google.authUrl(c.arena, config);
    return c.redirect(url);
}

fn callbackHandler(c: *spider.Ctx) !spider.Response {
    const code = c.query("code") orelse return c.redirect("/login");
    const profile = try spider.google.fetchProfile(c, code, config);
    // profile.id, profile.email, profile.name, profile.picture
    // ...
}
```
