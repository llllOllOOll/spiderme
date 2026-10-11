---
title: HTTP client
section: guide
order: 200
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

## Through a proxy

Some networks let nothing out except through a proxy, and some services only accept calls from an address they know, which a proxy with a fixed address provides. `proxy_url` sends a call through one:

```zig from=examples/guide/src/outbound_test.zig decl="proxy: the call asks the proxy for a way to the server, then goes through it"
```

- The address is `http://host:port` for an HTTP proxy, or `socks5://host:port` for a SOCKS5 one. A user and a password go in it: `http://user:pass@host:port`.
- The call asks the proxy for a tunnel to the server and talks to the server through it. With `https`, the proxy carries the bytes and cannot read them.
- Without `proxy_url`, the environment decides: `http_proxy`, `https_proxy` and `all_proxy`, with `no_proxy` for the hosts that go direct. With none of them set there is no proxy.

A `Client` takes its proxy when it is made, in `Client.init(io, allocator, .{ .base_url, .proxy_url })`, and keeps it:

```zig from=examples/guide/src/outbound_test.zig decl="proxy: a client is tied to the proxy it was made with"
```

## Showing a certificate (mTLS)

Some APIs, banks above all, want the caller to prove who it is with a certificate of its own. That is another function, `spider.http_client_mtls.request`:

```zig from=examples/guide/src/outbound_test.zig decl="client certificate: a server that is not there is an error by name"
```

- The certificate is `.pem` (the certificate and its key, as text) or `.pkcs12` (the bytes of a `.pfx` or `.p12` file and its password), the format certificate authorities usually hand out.
- The answer has `status` and `body`, and `res.json(T, allocator)` parses it. A 4xx or a 5xx is an answer, not an error. Free it with `res.deinit(allocator)`.
- `error.MtlsTransportFailed`: the server could not be reached or the handshake failed, a refused certificate included; the log has the reason. `error.MtlsTimeout` after `timeout_ms`, 30 seconds unless the call says otherwise.

It works differently from the rest of the client, and it shows:

- It runs the `curl` program, so `curl` has to be in the container. Zig's own TLS cannot present a certificate yet.
- The certificate and the key are written to files only the app's user can read, in `/tmp`, for the time of the call.
- The call blocks its thread until the answer comes, and it does not use a `Client`: every call opens a connection.
- The server's own certificate has to be one the system trusts. There is no option to trust a private authority.

The test above covers a server that is not there. A call that succeeds needs a server that asks for a certificate, which the tests of this site do not have.
