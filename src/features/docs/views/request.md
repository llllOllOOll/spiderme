-- doc

# Request

Access route parameters, parse JSON bodies, and read form or query string values directly from `spider.Ctx`.

## Route parameters

Access via `c.param("name")`:

```zig
fn userHandler(c: *spider.Ctx) !spider.Response {
    const id = c.param("id") orelse 
        return c.text("missing id", .{ .status = .bad_request });
    
    return c.json(.{ .id = id }, .{});
}
```

## JSON body parsing

Use `c.bodyJson()` to parse JSON into a struct:

```zig
const Task = struct { title: []const u8, done: bool };

pub fn createTask(c: *spider.Ctx) !spider.Response {
    const task = try c.bodyJson(Task);
    return c.json(task, .{});
}
```

## Form data

Use `c.parseForm()` to parse URL-encoded forms:

```zig
const LoginInput = struct { username: []const u8, password: []const u8 };

pub fn login(c: *spider.Ctx) !spider.Response {
    const input = try c.parseForm(LoginInput);
    // ...
}
```

## Query string

Use `c.query()` to get query parameters:

```zig
pub fn listUsers(c: *spider.Ctx) !spider.Response {
    const page = c.query("page") orelse "1";
    // ...
}
```

## Headers

Use `c.header()` for case-insensitive header lookup:

```zig
pub fn apiHandler(c: *spider.Ctx) !spider.Response {
    const auth = c.header("Authorization") orelse 
        return c.text("Unauthorized", .{ .status = .unauthorized });
    // ...
}
```

## Cookies

Use `c.cookie()` to read cookies:

```zig
pub fn profile(c: *spider.Ctx) !spider.Response {
    const session = c.cookie("session") orelse 
        return c.redirect("/login");
    // ...
}
```

## Check HTMX request

```zig
pub fn handler(c: *spider.Ctx) !spider.Response {
    if (c.isHtmx()) {
        // Return partial HTML for HTMX
        return c.html("<p>Partial content</p>", .{});
    }
    // Return full page
    return c.view("page", .{}, .{});
}
```
