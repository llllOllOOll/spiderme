---
title: Requests
section: guide
order: 20
---

# Requests

A handler receives `c: *spider.Ctx`. Everything the client sent is read through it: path parameters, the query string, headers, cookies and the body.

## Path and query

`c.params.get` reads a `:name` segment of the route. `c.query` reads a query string value as it was sent; `c.queryDecoded` also decodes it, which is what you want for text a person typed.

```zig
fn listPosts(c: *spider.Ctx) !spider.Response {
    const author = c.params.get("author") orelse return error.NotFound;
    const page = c.query("page") orelse "1";
    const search = c.queryDecoded("q") orelse "";
    return c.json(.{ .author = author, .page = page, .search = search }, .{});
}
```

All three return `?[]const u8`: null when the value is not there.

## Headers and cookies

Header names are matched without regard to case.

```zig
fn whoAmI(c: *spider.Ctx) !spider.Response {
    const agent = c.header("User-Agent") orelse "unknown";
    const session = c.cookie("session") orelse return error.Unauthorized;
    const name = c.cookieDecoded("name") orelse "stranger";
    return c.json(.{ .agent = agent, .session = session, .name = name }, .{});
}
```

`c.cookie` gives the value as the browser sent it. `c.cookieDecoded` also decodes it: use it for a cookie that was written with `.encode`, as [Responses](/docs/response) shows.

Returning `error.Unauthorized` answers 401. `error.NotFound` answers 404 and `error.Forbidden` 403.

## JSON body

`c.bodyJson` parses the body into a struct. Fields the struct does not have are ignored; a field with a default value may be left out by the client.

```zig
const NewPost = struct {
    title: []const u8,
    draft: bool = false,
};

fn createPost(c: *spider.Ctx) !spider.Response {
    const post = try c.bodyJson(NewPost);
    return c.json(.{ .title = post.title, .draft = post.draft }, .{ .status = .created });
}
```

A body that is missing or does not match the struct answers 400.

## Forms

`c.parseForm` reads an HTML form, urlencoded or multipart, into a struct. A field can be text, a number, a `bool`, or an optional of those.

```zig
const SignIn = struct {
    email: []const u8,
    remember: bool,
    age: ?u32,
};

fn signIn(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(SignIn);
    if (form.email.len == 0) return error.BadRequest;
    return c.redirect("/");
}
```

A field the form did not send is an empty string, zero or `false`; an optional one is null.

## Typed parameters

Instead of reading and converting a value yourself, a handler can ask for it in its parameters. `spider.Path` takes a path segment as a number or text, `spider.Form` takes the form. A value that does not convert answers 400 before the handler runs.

```zig
fn updatePost(id: spider.Path(i64, "id"), form: spider.Form(NewPost), c: *spider.Ctx) !spider.Response {
    return c.json(.{ .id = id.value, .title = form.value.title }, .{});
}
```

The parameters can come in any order.
