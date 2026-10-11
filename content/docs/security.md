---
title: Security in production
section: guide
order: 210
---

# Security in production

In production an app usually sits behind a proxy that holds the certificate and passes requests on. This page is about what Spider does on that road before a handler runs, what is on by default, and what the app has to say.

The code is from `examples/guide` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/guide)): a small server kept as tests, for what the example apps do not use.

```zig from=examples/guide/spider.config.zig
```

```zig from=examples/guide/src/server.zig decl=run
```

## Posts from another site

A page on another site can make a visitor's browser post a form to your app, with the visitor's cookies: that is CSRF. Spider refuses it before any route is looked at, and it is on by default. There is no token to put in forms.

A browser says where a request comes from. A request that changes something (anything but GET, HEAD and OPTIONS) and comes from another site gets a 403. The app's own pages pass, and so does a program that is not a browser (a script, a webhook, another server): it carries nobody's cookies.

```zig from=examples/guide/src/security_test.zig decl="cross-site: a form on another site cannot post here; the app's own pages and other programs can"
```

Some posts from another site are expected: a payment or login provider that sends the visitor's browser back with a form. `Config.origin_check` names them, by path (`exempt_paths`) or by who sends them (`trusted_origins`, full origins such as `https://auth.example.com`):

```zig from=examples/guide/src/security_test.zig decl="cross-site: a path the config exempts takes posts from anywhere"
```

The same check refuses a WebSocket opened from another site.

## HTTPS

The proxy talks to the app over plain HTTP and says in a header which one the visitor used. `spider.forceHttps` sends a visitor who came over HTTP to the same address on HTTPS:

```zig from=examples/guide/src/security_test.zig decl="https: a request that came over plain HTTP is sent to the HTTPS address"
```

- `.default_base_url` is the public address of the app. The `BASE_URL` variable replaces it when it is set.
- The header is `X-Forwarded-Proto` (`.proto_header` changes it). A request without the header is taken as HTTPS: that is development, with no proxy.
- A route with `.allow_http = true` is not redirected: for a caller that cannot follow a redirect, such as some webhooks. `.allow_http_paths` does the same for paths that are not routes.

## The visitor's address

Behind a proxy, every connection comes from the proxy. The visitor's address is in the `X-Forwarded-For` header, which anyone can also write themselves. `c.clientIp()` believes the header only when the connection comes from a proxy listed in `Config.trusted_proxies`, and then takes the address that proxy saw:

```zig from=examples/guide/src/server.zig decl=whoami
```

```zig from=examples/guide/src/security_test.zig decl="the visitor's address: what the trusted proxy wrote, not what the visitor claims"
```

`trusted_proxies` takes addresses or ranges (`"10.0.0.0/8"`). Empty, the default, the header is ignored and `c.clientIp()` is the address of the connection. Use `c.clientIp()` for logs, audit and rate limits, and never read the header yourself.

## One id per request

Every request has an id. It is in the log line, in the `X-Request-Id` header of the answer and in `c.requestId()`, so a visitor's report, the proxy's log and the app's log can be matched. An id the proxy already gave is kept:

```zig from=examples/guide/src/security_test.zig decl="request id: the proxy's is kept, and comes back in the answer"
```

## Limits that are already on

Set in `spider.config.zig`; the values are the defaults.

- `max_body_bytes` (10 MiB): a larger request body gets a 413, before it is read when it declares its length. Raise it for an app that takes files.
- `header_timeout_ms` (30 s): how long a client has to send the head of a request.
- `body_timeout_ms` (60 s): the longest silence while a body arrives. A slow but steady upload is not cut.
- `keepalive_timeout_ms` (120 s): how long an idle connection is kept. Keep it above the proxy's own idle time.
- `stream_write_timeout_ms` (10 s): a stream whose reader stopped reading is dropped.

None of them applies while a handler runs.

## Who may call each route

A route says who may call it in its config (see [Router](/docs/router) and [Policies](/docs/policies)). With `require_route_access = true` in the config, or `server.requireRouteAccess()`, the server refuses to start while a route says nothing, and names it: a forgotten rule becomes an error at start instead of an open door. `spider routes --check` does the same check from the command line.

## What reaches the page

A template escapes every value it prints, and [Markdown](/docs/markdown) escapes what the author typed. Text reaches a page as HTML only through `spider.RawHtml`: search the code for it when reviewing.
