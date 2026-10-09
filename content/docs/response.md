---
title: Responses
section: guide
order: 30
---

# Responses

A handler returns a `spider.Response`. `c` builds it: every helper takes the content and an options struct, and `.{}` means status 200 with no extra headers.

Where it can, this page shows code from Posts, the example app in `examples/posts`.

## JSON

`c.json` takes any struct, including one written in place, and turns it into JSON. The API of Posts answers one post like this:

```zig from=examples/posts/src/features/posts/api.zig decl=show,asJson,PostJson
```

## Status and headers

The options set the status and add headers. After saving a post the API answers 201, with the address of the new post in `Location`:

```zig from=examples/posts/src/features/posts/api.zig decl=create
```

`.status` is a `std.http.Status`: `.created`, `.no_content`, `.not_found` and so on. Headers are a slice of name and value pairs; one built while the request runs comes from `c.arena`, as here, so it is still there when the response is sent.

## Text and HTML

`c.text` and `c.html` answer a string as it is:

```zig
fn hello(c: *spider.Ctx) !spider.Response {
    return c.text("Hello", .{});
}

fn banner(c: *spider.Ctx) !spider.Response {
    return c.html("<h1>Hello</h1>", .{});
}
```

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

```zig from=examples/posts/src/main.zig decl=onError,fallback,api_errors
```

To say more about a 400, set the detail before returning the error, as the API does for a `?limit=` that is not a number:

```zig from=examples/posts/src/features/posts/api.zig decl=list
```

To choose the whole body yourself, return a response with the status, as `create` above does with its 422. In Zig, a JSON key named `error` is written `.@"error"`.

## Templates

`c.view` renders a template with the data you give it, and its options set the status like any other response. Posts shows its form again with 422 when a field is missing:

```zig from=examples/posts/src/features/posts/controller.zig decl=form
```

[Templates](/docs/templates) explains the files.

## Cookies

`c.withCookie` gives back the options with a `Set-Cookie` header in them. A cookie is `HttpOnly`, `Secure` and `SameSite=Lax` unless you say otherwise.

A cookie cannot hold every character. For text a person typed, such as a name with an accent or a semicolon, pass `.encode = true`, and read the cookie back with `c.cookieDecoded`. The `saved` function above does both: it remembers the author's name for a year.

## Files

`c.download` sends bytes as a file the browser saves. The file name may come from user data: it is made safe before it is sent. Posts exports its posts as a CSV file:

```zig from=examples/posts/src/features/posts/controller.zig decl=exportCsv
```
