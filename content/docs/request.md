---
title: Requests
section: guide
order: 20
---

# Requests

A handler receives `c: *spider.Ctx`. Everything the client sent is read through it: path parameters, the query string, headers, cookies and the body.

Where it can, this page shows code from Posts, the example app in `examples/posts`.

## Path and query

`c.params.get` reads a `:name` segment of the route. Posts reads the `:id` of `/posts/:id` this way:

```zig from=examples/posts/src/features/posts/controller.zig decl=load
```

`c.queryDecoded` reads a value of the query string, decoded: what you want for text a person typed. The feed of Posts uses it for its search, `/posts?q=router`:

```zig from=examples/posts/src/features/posts/controller.zig decl=index
```

`c.query` reads the value as it was sent, without decoding, which is fine for a number. All three return `?[]const u8`: null when the value is not there. The API of Posts takes a `?limit=`:

```zig from=examples/posts/src/features/posts/api.zig decl=list
```

## Cookies

`c.cookie` gives the value of a cookie as the browser sent it. `c.cookieDecoded` also decodes it: use it for a cookie that was written with `.encode`, as [Responses](/docs/response) shows.

Posts remembers the email of the last sign-in on a browser, and has it typed when the sign-in form opens:

```zig from=examples/posts/src/features/auth/controller.zig decl=loginForm
```

## Headers

`c.header` reads a request header. Names are matched without regard to case. The JSON API of Posts asks for a key in one:

```zig from=examples/posts/src/features/posts/api.zig decl=requireKey
```

Returning `error.Unauthorized` answers 401. `error.NotFound` answers 404 and `error.Forbidden` 403.

## JSON body

`c.bodyJson` parses the body into a struct. Fields the struct does not have are ignored; a field with a default value may be left out by the client. Posts takes a new post as JSON with the same struct its form uses:

```zig from=examples/posts/src/features/posts/api.zig decl=create
```

A body that is missing, or is not JSON that fits the struct, answers 400.

## Forms

`c.parseForm` reads an HTML form, urlencoded or multipart, into a struct. A field can be text, a number, a `bool`, or an optional of those. This is what the form of a post sends:

```zig from=examples/posts/src/features/posts/model.zig decl=Input
```

And the handler that receives it:

```zig from=examples/posts/src/features/posts/controller.zig decl=create
```

A field the form did not send is an empty string, zero or `false`; an optional one is null. `create` checks the fields itself and shows the form again when one is missing. The form has no author field: the author is whoever is signed in.

## Typed parameters

Instead of reading and converting a value yourself, a handler can ask for it in its parameters. `spider.Path` takes a path segment as a number or text, and `spider.Form` takes the form. A value that does not convert answers 400 before the handler runs.

```zig from=examples/posts/src/features/posts/api.zig decl=show
```

The value is in `.value`. The parameters can come in any order.
