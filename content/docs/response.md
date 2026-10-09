---
title: Responses
section: guide
order: 30
---

# Responses

A handler returns a `spider.Response`. `c` builds it: every helper takes the content and an options struct, and `.{}` means status 200 with no extra headers.

Where it can, this page shows code from Posts, the example app in `examples/posts`.

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

`c.redirect` answers 302 with the address in `Location`. Posts goes back to the feed after deleting a post:

```zig from=examples/posts/src/features/posts/controller.zig decl=delete
```

After a form is saved, use `c.redirectWith`. It answers 303, which tells the browser to load the next page with a GET, and its options can carry headers and cookies. Posts goes to the post it just saved, and remembers who wrote it:

```zig from=examples/posts/src/features/posts/controller.zig decl=saved
```

## Errors

A handler that returns an error ends the request with the matching status: `error.NotFound` is 404, `error.Unauthorized` 401, `error.Forbidden` 403 and `error.BadRequest` 400. Any other error is 500.

Posts returns `error.NotFound` for a post that does not exist:

```zig from=examples/posts/src/features/posts/controller.zig decl=load
```

What the visitor then sees is decided in one place, the error handler given to `onError` in `src/main.zig`. Posts shows its own page for a 404 and leaves the rest to Spider:

```zig from=examples/posts/src/main.zig decl=onError,fallback
```

To say more about a 400, set the detail before returning the error:

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

`c.view` renders a template with the data you give it, and its options set the status like any other response. Posts shows its form again with 422 when a field is missing:

```zig from=examples/posts/src/features/posts/controller.zig decl=form
```

[Templates](/docs/templates) explains the files.

## Cookies

`c.withCookie` gives back the options with a `Set-Cookie` header in them. A cookie is `HttpOnly`, `Secure` and `SameSite=Lax` unless you say otherwise.

```zig
fn signIn(c: *spider.Ctx) !spider.Response {
    const opts = try c.withCookie("session", "abc123", .{ .max_age = 3600 });
    return c.text("signed in", opts);
}
```

A cookie cannot hold every character. For text a person typed, such as a name with an accent or a semicolon, pass `.encode = true`, and read the cookie back with `c.cookieDecoded`. The `saved` function above does that for the author's name.

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
