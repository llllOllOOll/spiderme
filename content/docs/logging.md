---
title: Logging
section: guide
order: 250
---

# Logging

An app writes two kinds of lines: one per request, which Spider writes, and its own. Both go to stderr, which is where a container's log comes from.

## One line per request

`spider.logger` is a middleware. A new project already uses it, first in the list so that it sees every request:

```zig from=examples/posts/src/main.zig decl=serve
```

These are real lines, from the tests of `examples/guide`:

```text
2026-10-11T01:08:09.561Z [200] GET    /whoami  0.1ms  rid=e9bb9c3eed2e9d0f user=- org=-
2026-10-11T01:08:09.562Z [200] GET    /whoami  0.0ms  rid=edge-7f3a user=- org=-
2026-10-11T01:08:09.564Z [201] POST   /photos  0.1ms  rid=62c5554d6cf5b07b user=- org=-
2026-10-11T01:08:09.561Z [302] GET    /whoami  0.0ms  rid=966935a5b3ec2217 user=- org=-
2026-10-11T01:08:09.567Z [400] POST   /photos  0.0ms  rid=783d14f26f44a02c user=- org=-  error=InvalidBoundary
2026-10-11T01:09:23.829Z [200] GET    /ticks  stream 0ms  rid=821c48ffbb00920e user=- org=-
```

What a line says, in order:

- The time, in UTC.
- The status, the method and the path. The query string is left out: it can carry a token.
- How long the handler and the middlewares took.
- `rid`: the id of the request, the same one the answer carries in `X-Request-Id` and `c.requestId()` gives. A proxy's id is kept (`edge-7f3a` above): see [Security in production](/docs/security).
- `user` and `org`: who was signed in, as an id and never a name or an e-mail. `-` for a visitor.
- `error`: the name of the error a handler returned, when it returned one.

A stream (SSE or WebSocket) gets its line when it ends, with how long it stayed open after the word `stream`.

On a terminal the status is colored. In a container's log it is plain text.

## Leaving out the noise

Some requests say nothing: a health check every five seconds, a page that polls. Two ways to leave them out, and both keep the line when the request fails (a status of 400 or more), so an error is never hidden.

On the route, with `.quiet_log`:

```zig from=examples/bookings/src/features/home/routes.zig decl=build
```

Or by path, for what is not a route of the app (files, a path a middleware answers). `spider.loggerWith` takes the place of `spider.logger`:

```zig from=examples/guide/src/server.zig decl=run
```

In a pattern, `*` is one segment of the path and `**` at the end is everything under it: `"/tickets/*/presence"`, `"/assets/**"`.

## The app's own lines

Use `std.log`, as any Zig program does:

```zig from=examples/bookings/src/features/bookings/jobs.zig decl=expireHolds
```

By default those lines have no time. `spider.logFn` adds it, in the format of the request lines:

```zig from=examples/guide/src/logging_test.zig decl=std_options
```

```text
2026-10-11T01:09:14.868Z info: 3 hold(s) ran out and were released
2026-10-11T01:09:14.868Z warning: the webhook was not told about booking 53
2026-10-11T01:09:14.868Z error (mail): the provider answered 502
```

`(mail)` is a scope: `const log = std.log.scoped(.mail);` gives a logger whose lines carry that word.

Two things to know about levels:

- A release build drops the `debug` lines and keeps the rest. `.log_level = .debug` in `std_options` keeps them too.
- A test fails when the code it runs logs at `.err`. Code that fails on purpose in a test logs at `.warn`.

## What not to log

A log is read by more people than a database. Do not write passwords, tokens, cookies or the body of a request to it, and prefer an id to a name or an e-mail. Spider's own lines follow that: no query string, no body, ids for who is signed in.
