---
title: Middleware
section: guide
order: 40
---

# Middleware

A middleware is a function that runs around a handler. It can stop the request, let it through, or change the response on the way back.

## Writing one

It receives the request and `next`, the rest of the chain. Calling `next(c)` runs the handler and gives back its response.

```zig
fn requireKey(c: *spider.Ctx, next: spider.NextFn) anyerror!spider.Response {
    const key = c.header("X-Api-Key") orelse return error.Unauthorized;
    if (!std.mem.eql(u8, key, "secret")) return error.Forbidden;
    return next(c);
}
```

Not calling `next` ends the request there: the handler never runs.

## Changing the response

Call `next` first, then work on what came back. Memory for the request comes from `c.arena` and is freed when the request ends.

```zig
fn poweredBy(c: *spider.Ctx, next: spider.NextFn) anyerror!spider.Response {
    var res = try next(c);
    const headers = try c.arena.alloc([2][]const u8, res.headers.len + 1);
    @memcpy(headers[0..res.headers.len], res.headers);
    headers[res.headers.len] = .{ "X-Powered-By", "Spider" };
    res.headers = headers;
    return res;
}
```

## Registering

`use` puts a middleware on every request. `useAt` puts it on the paths under a prefix.

```zig
server
    .use(spider.logger)
    .use(poweredBy)
    .useAt("/api/*", requireKey)
    .mountFeatures(features)
    .listen(.{}) catch |err| return err;
```

They run in the order they were added: first every `use`, then every `useAt` that matches.

## One group of routes

A group can have its own middleware. It runs for the routes of that group only, after the ones registered on the server.

```zig
pub fn build() spider.Group {
    var g = spider.Group.init("/admin");
    _ = g.use(requireKey);
    _ = g.get("/", dashboard, .{ .public = true });
    return g;
}
```

## Ready-made

- `spider.logger` prints one line per request: status, method, path and time.
- `spider.gzip` compresses responses for clients that accept it.
- `spider.varyHtmx` adds `Vary: HX-Request` to HTML responses.
- `spider.forceHttps(.{ .default_base_url = "https://example.com" })` redirects plain HTTP to HTTPS behind a proxy.

## Errors

An error returned by a handler or a middleware goes to the error handler. `spider.errorHandler` is the ready-made one, and apps created by the command line tool use it. To write your own, give `onError` a function:

```zig
fn onError(c: *spider.Ctx, err: anyerror) anyerror!spider.Response {
    return c.json(.{ .@"error" = @errorName(err) }, .{ .status = spider.statusForError(err) });
}
```

`spider.statusForError` is the default mapping from an error to a status.
