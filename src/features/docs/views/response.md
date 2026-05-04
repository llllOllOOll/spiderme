-- doc

# Response

Spider provides multiple ways to return responses from handlers via `spider.Ctx`.

## JSON response

Use `c.json(value, opts)` to return JSON:

```zig
fn apiHandler(c: *spider.Ctx) !spider.Response {
    return c.json(.{ .id = 42, .name = "Alice" }, .{});
}
```

Returns `{"id":42,"name":"Alice"}` with `content-type: application/json`.

## HTML response

Use `c.html(content, opts)` for raw HTML:

```zig
fn pageHandler(c: *spider.Ctx) !spider.Response {
    return c.html("<h1>Hello</h1>", .{});
}
```

## Text response

Use `c.text(content, opts)` for plain text:

```zig
fn pingHandler(c: *spider.Ctx) !spider.Response {
    return c.text("pong", .{});
}
```

## Template rendering

Use `c.view(name, data, opts)` to render a template:

```zig
fn homeHandler(c: *spider.Ctx) !spider.Response {
    return c.view("home/index", .{ .title = "Home" }, .{});
}
```

## Redirect

Use `c.redirect(url)` to redirect:

```zig
fn loginHandler(c: *spider.Ctx) !spider.Response {
    return c.redirect("/dashboard");
}
```

## Custom status and headers

Pass `ResponseOptions` to customize status and headers:

```zig
fn customHandler(c: *spider.Ctx) !spider.Response {
    const headers = try c.arena.alloc([2][]const u8, 1);
    headers[0] = .{ "X-Custom", "value" };
    return c.json(.{ .ok = true }, .{ .status = .created, .headers = headers });
}
```

## ResponseOptions

```zig
pub const ResponseOptions = struct {
    status: std.http.Status = .ok,
    headers: []const [2][]const u8 = &.{},
    cookies: []const [2][]const u8 = &.{},
};
```

**Important:** Always allocate headers in `c.arena` (per-request allocator). Never use stack allocation for headers.
