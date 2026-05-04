-- doc

# Middleware

Middlewares wrap handlers, allowing you to run code before and/or after the main handler. They have access to `spider.Ctx` and the `next` function.

## Basic Middleware

```zig
fn loggingMiddleware(c: *spider.Ctx, next: spider.NextFn) !spider.Response {
    std.debug.print("[{s}] {s}\n", .{ c.getMethod(), c.getPath() });
    const res = try next(c);
    return res;
}
```

Register with `.use()`:

```zig
var server = spider.app();
server
    .use(loggingMiddleware)
    .get("/", homeHandler);
```

## Protecting Routes

```zig
fn authMiddleware(c: *spider.Ctx, next: spider.NextFn) !spider.Response {
    const token = c.header("Authorization") orelse 
        return c.text("Unauthorized", .{ .status = .unauthorized });
    // verify token...
    return next(c);
}

// Global
server.use(authMiddleware);

// Path-scoped
server.useAt("/api/*", authMiddleware);

// Route-specific
server.addRoute(.GET, "/admin", &.{authMiddleware}, adminHandler);
```

## Modifying the Response

```zig
fn addHeaderMiddleware(c: *spider.Ctx, next: spider.NextFn) !spider.Response {
    const res = try next(c);
    const new_headers = try c.arena.alloc([2][]const u8, 1);
    new_headers[0] = .{ "X-Powered-By", "Spider" };
    return spider.Response{
        .status = res.status,
        .body = res.body,
        .content_type = res.content_type,
        .headers = new_headers,
    };
}
```

## Error Handling

```zig
fn errorHandler(c: *spider.Ctx, err: anyerror) !spider.Response {
    std.debug.print("Error: {s}\n", .{@errorName(err) });
    return c.json(.{ .error = @errorName(err) }, .{ .status = .internal_server_error });
}

server.onError(errorHandler);
```

## Chain Order

Middlewares execute in order:

```zig
server
    .use(middleware1)  // runs first
    .use(middleware2)  // runs second
    .get("/", handler);  // runs last
```

For path-scoped middlewares, they run AFTER global middlewares but BEFORE the handler.
