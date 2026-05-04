-- doc 

# Router

Spider uses a trie-based router supporting static routes, dynamic parameters (`:param`), and wildcards (`*`). Routes are chained on the server and dispatched per HTTP method.

## Basic routing

```zig
const spider = @import("spider");

pub fn main(init: std.process.Init) !void {
    var server = spider.app();
    defer server.deinit();

    server
        .get("/", homeHandler)
        .post("/users", createUser)
        .get("/users/:id", getUser)
        .listen(8080) catch {};
}
```

## Dynamic parameters

Access via `c.param("name")`:

```zig
fn userHandler(c: *spider.Ctx) !spider.Response {
    const id = c.param("id") orelse 
        return c.text("missing id", .{ .status = .bad_request });
    
    return c.json(.{ .id = id }, .{});
}
```

## Wildcards

Matches anything after the prefix: `/assets/*` matches `/assets/logo.png`, `/assets/css/main.css`, etc.

```zig
server.get("/assets/*", spider.static.serve);
```

## Method chaining

Chain multiple methods on the same base path using `addRoute`:

```zig
server
    .get("/users", listUsers)
    .post("/users", createUser)
    .get("/users/:id", getUser)
    .put("/users/:id", updateUser)
    .delete("/users/:id", deleteUser);
```

## Global middleware

Use `.use(middlewareFn)` to apply middleware to all routes:

```zig
fn loggingMiddleware(c: *spider.Ctx, next: spider.NextFn) !spider.Response {
    std.debug.print("[{s}] {s}\n", .{ c.getMethod(), c.getPath() });
    return next(c);
}

server
    .use(loggingMiddleware)
    .get("/", homeHandler);
```

## Path-scoped middleware

Use `.useAt(path, middlewareFn)` to scope middleware to a path pattern:

```zig
fn authMiddleware(c: *spider.Ctx, next: spider.NextFn) !spider.Response {
    if (c.header("Authorization") == null) {
        return c.text("Unauthorized", .{ .status = .unauthorized });
    }
    return next(c);
}

server
    .useAt("/api/*", authMiddleware)
    .get("/api/users", listUsers)
    .get("/api/data", getData);
```

## Route groups

Group routes under a common prefix with shared middleware:

```zig
fn apiRoutes(s: *spider.Server, prefix: []const u8, mws: []const spider.MiddlewareFn) void {
    s.addRoute(.GET, "/users", mws, listUsers);
    s.addRoute(.POST, "/users", mws, createUser);
}

server.group("/api", &.{authMiddleware}, apiRoutes);
```

Inside the group function, use `s.addRoute()` to register routes with the shared middleware.

## Route-specific middleware

Pass middleware directly to `addRoute`:

```zig
server.addRoute(
    .GET,
    "/admin/dashboard",
    &.{authMiddleware, adminMiddleware},
    dashboardHandler
);
```

## Error handler

Set a global error handler with `.onError()`:

```zig
fn errorHandler(c: *spider.Ctx, err: anyerror) !spider.Response {
    return c.json(.{ .error = @errorName(err) }, .{ .status = .internal_server_error });
}

server
    .onError(errorHandler)
    .get("/", homeHandler);
```
