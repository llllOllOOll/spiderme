---
title: HTTP client
section: guide
order: 56
---

# HTTP client

`spider.http_client` calls other servers: an API, a webhook, a payment provider.

The code on this page is from [Bookings](https://bookings.spiderme.org), the example app in `examples/bookings` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/bookings)). When a booking is confirmed it tells an address of the office's choosing, so that another system can follow along.

## A request

```zig from=examples/bookings/src/features/bookings/notify.zig decl=Event,call
```

`post` takes the server's `io`, where to keep the answer, the address and the options. In a handler those are `c.io()` and `c.arena`. There is one function for each method: `get`, `post`, `put`, `patch`, `delete` and `head`.

The options used most:

- `.body`: `.{ .json = text }`, `.{ .form = pairs }` or `.{ .raw = bytes }`. Only `post`, `put` and `patch` take one.
- `.headers`: `&.{.{ .name = "Authorization", .value = token }}`.
- `.query`: pairs added to the address as its query string, encoded for you.
- `.timeout_ms`: see below.

## The answer

The answer has a `status` and the body as `body_text`. `res.json(T)` parses the body as JSON into a struct, which is then in its `.value`. Call `res.deinit()` when done with it.

An answer of 400 or 500 is still an answer: the call succeeds and the status says what happened. Check it, as `call` does above. The call itself fails only when there was no answer to have: the server could not be reached, or the time ran out.

A redirect is not followed. The client goes where you send it and nowhere else.

## Always say how long to wait

Without `.timeout_ms` a request waits for as long as the other server takes, and so does the visitor whose request made it. Give every call a limit that fits what it is for: Bookings gives its webhook three seconds. Past the limit the call fails with `error.Timeout`.

Then decide what a failure means. Someone else's server being down should rarely stop your own from doing its job:

```zig from=examples/bookings/src/features/bookings/notify.zig decl=confirmed
```

A test points the address at a port nobody listens on, and the booking is confirmed all the same:

```zig from=examples/bookings/src/pages_test.zig decl="booking: a webhook that is down does not undo the confirmation"
```

## Many calls to the same server

Each of the functions above opens a connection and closes it. An app that keeps calling the same server makes a client once and reuses its connections:

```zig from=examples/bookings/src/pages_test.zig decl="http client: one client for many calls to the same server"
```

## Testing

The test of the webhook starts a small server of its own, points the app at it, and reads what arrived:

```zig from=examples/bookings/src/pages_test.zig decl=Hook
```
