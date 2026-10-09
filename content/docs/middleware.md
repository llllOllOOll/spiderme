---
title: Middleware
section: guide
order: 40
---

# Middleware

A middleware is a function that runs around a handler. It can stop the request, let it through, or change the response on the way back.

The code on this page is from Posts, the example app in `examples/posts`. Its JSON API has two middlewares.

## Writing one

It receives the request and `next`, the rest of the chain. Calling `next(c)` runs the handler and gives back its response.

```zig from=examples/posts/src/features/posts/api.zig decl=requireKey
```

Not calling `next` ends the request there: the handler never runs.

## Changing the response

Call `next` first, then work on what came back. Memory for the request comes from `c.arena` and is freed when the request ends.

```zig from=examples/posts/src/features/posts/api.zig decl=noStore
```

## One group of routes

A group can have its own middlewares. They run for the routes of that group only, in the order they were added:

```zig from=examples/posts/src/features/posts/routes.zig decl=api
```

The pages of Posts are another group, and neither middleware touches them.

## The whole app

`use` on the server puts a middleware on every request, before the ones of a group. Posts has two: the logger, and the one that reads the login cookie.

```zig from=examples/posts/src/main.zig decl=serve
```

`server.useAt("/admin/*", check)` puts one on every path under a prefix instead, whatever group the routes are in.

## Ready-made

- `spider.logger` prints one line per request: status, method, path and time.
- `spider.session.middleware()` reads the login cookie and tells the routes who is signed in. See [Login](/docs/auth).
- `spider.gzip` compresses responses for clients that accept it.
- `spider.varyHtmx` adds `Vary: HX-Request` to HTML responses.
- `spider.forceHttps(.{ .default_base_url = "https://example.com" })` redirects plain HTTP to HTTPS behind a proxy.

## Errors

An error returned by a handler or a middleware goes to the error handler given to `onError`. `spider.errorHandler` is the ready-made one, and a new project uses it. Posts wraps it in a function of its own, to answer the API in JSON and to show its 404 page:

```zig from=examples/posts/src/main.zig decl=onError,fallback,api_errors
```
