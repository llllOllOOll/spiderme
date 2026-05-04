-- doc

# Group Routes

Group routes under a common prefix with shared middleware.

## Basic Group#

```zig
fn adminRoutes(s: *spider.Server, prefix: []const u8, mws: []const spider.MiddlewareFn) void {
    s.addRoute(.GET, "/admin/users", mws, listUsers);
    s.addRoute(.GET, "/admin/settings", mws, showSettings);
    s.addRoute(.POST, "/admin/settings", mws, saveSettings);
}

var server = spider.app();
server.group("/admin", &.{authMiddleware}, adminRoutes);
```

The `prefix` is the group prefix (`"/admin"`), `mws` is the shared middleware slice.

## With Middleware#

```zig
fn apiRoutes(s: *spider.Server, prefix: []const u8, mws: []const spider.MiddlewareFn) void {
    s.addRoute(.GET, "/api/users", mws, listUsers);
    s.addRoute(.POST, "/api/users", mws, createUser);
}

const apiMiddleware = [_]spider.MiddlewareFn{ authMiddleware, logMiddleware };

server.group("/api", &apiMiddleware, apiRoutes);
```

## Inside Group Function#

Use `s.addRoute()` inside the group function to register routes with shared middleware:

```zig
fn dashRoutes(s: *spider.Server, prefix: []const u8, mws: []const spider.MiddlewareFn) void {
    // These routes automatically get the group's prefix and middleware
    s.addRoute(.GET, "/dashboard", mws, showDashboard);
    s.addRoute(.GET, "/dashboard/stats", mws, showStats);
}
```

## Route-Specific Middleware#

Add extra middleware for specific routes within the group:

```zig
fn adminRoutes(s: *spider.Server, prefix: []const u8, mws: []const spider.MiddlewareFn) void {
    // Shared middleware + route-specific middleware
    const extra_mw = [_]spider.MiddlewareFn{ auditMiddleware };
    s.addRoute(.DELETE, "/admin/users/:id", extra_mw[0..], deleteUser);
}
```

## Nested Groups#

Groups don't support nesting directly, but you can compose prefixes:

```zig
fn apiV1Routes(s: *spider.Server, prefix: []const u8, mws: []const spider.MiddlewareFn) void {
    s.addRoute(.GET, "/v1/users", mws, listUsersV1);
}

server.group("/api", &.{authMiddleware}, apiV1Routes);
```
