---
title: Responses
section: guide
order: 30
---

# Responses

A handler returns a `spider.Response`. `c` builds it: every helper takes the content and an options struct, and `.{}` means status 200 with no extra headers.

## Text, JSON and HTML

```zig
fn hello(c: *spider.Ctx) !spider.Response {
    return c.text("Hello", .{});
}

fn version(c: *spider.Ctx) !spider.Response {
    return c.json(.{ .name = "myapp", .version = 3 }, .{});
}

fn banner(c: *spider.Ctx) !spider.Response {
    return c.html("<h1>Hello</h1>", .{});
}
```

`c.json` takes any struct, including one written in place, and turns it into JSON.

## Status and headers

```zig
fn create(c: *spider.Ctx) !spider.Response {
    return c.json(.{ .id = 7 }, .{
        .status = .created,
        .headers = &.{.{ "Location", "/posts/7" }},
    });
}
```

`.status` is a `std.http.Status`: `.created`, `.no_content`, `.not_found` and so on.

## Redirects

```zig
fn old(c: *spider.Ctx) !spider.Response {
    return c.redirect("/posts");
}
```

It answers 302 with the address in `Location`.

After a form is saved, use `c.redirectWith`. It answers 303, which tells the browser to load the next page with a GET, and its options can carry headers and cookies.

```zig
fn save(c: *spider.Ctx) !spider.Response {
    return c.redirectWith("/posts/7", .{});
}
```

## Errors

A handler that returns an error ends the request with the matching status: `error.NotFound` is 404, `error.Unauthorized` 401, `error.Forbidden` 403 and `error.BadRequest` 400. Any other error is 500.

```zig
fn show(c: *spider.Ctx) !spider.Response {
    const id = c.params.get("id") orelse return error.NotFound;
    if (id.len > 20) {
        c.setErrorDetail("the id is too long");
        return error.BadRequest;
    }
    return c.text(id, .{});
}
```

To choose the body yourself, return a response with the status. In Zig, a JSON key named `error` is written `.@"error"`.

```zig
fn missing(c: *spider.Ctx) !spider.Response {
    return c.json(.{ .@"error" = "no such post" }, .{ .status = .not_found });
}
```

## Templates

`c.view` renders a template with the data you give it. The name is the feature and the file: `"posts/index"` is `src/features/posts/views/index.html`.

```zig
fn index(c: *spider.Ctx) !spider.Response {
    return c.view("posts/index", .{ .title = "Posts", .count = 3 }, .{});
}
```

## Cookies

`c.withCookie` gives back the options with a `Set-Cookie` header in them. A cookie is `HttpOnly`, `Secure` and `SameSite=Lax` unless you say otherwise.

```zig
fn signIn(c: *spider.Ctx) !spider.Response {
    const opts = try c.withCookie("session", "abc123", .{ .max_age = 3600 });
    return c.text("signed in", opts);
}
```

A cookie cannot hold every character. For text a person typed, such as a name with an accent or a semicolon, pass `.encode = true`, and read the cookie back with `c.cookieDecoded`.

```zig
const Profile = struct { name: []const u8 };

fn saveName(c: *spider.Ctx) !spider.Response {
    const profile = try c.parseForm(Profile);
    const opts = try c.withCookie("name", profile.name, .{ .encode = true, .max_age = 3600 });
    return c.redirectWith("/", opts);
}
```

## Files

`c.download` sends bytes as a file the browser saves. The file name may come from user data: it is made safe before it is sent.

```zig
fn report(c: *spider.Ctx) !spider.Response {
    const csv = "name,total\nAna,3\n";
    return c.download(csv, .{
        .filename = "report.csv",
        .content_type = spider.content_types.csv,
    });
}
```
