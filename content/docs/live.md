---
title: Live pages (SSE)
section: guide
order: 150
---

# Live pages (SSE)

A page that shows what other people are doing goes stale while it is open. With server-sent events (SSE) the page keeps one connection to the server, and the server says on it when something changed. It is plain HTTP: no other port, no other protocol, and the browser connects again by itself when the connection drops.

The code on this page is from [Bookings](https://bookings.spiderme.org), the example app in `examples/bookings` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/bookings)). Its day view shows every room's bookings; when someone books, confirms or cancels, everyone looking at that day sees it without reloading.

## A stream is a route

```zig from=examples/bookings/src/features/home/routes.zig decl=build
```

`sseWith` takes the same config as any route: this stream is `.public`. With `.authenticated`, `.roles` or `.policy`, the check runs before the stream opens, and a visitor who does not pass gets the same answer as on any other route. `.quiet_log` keeps a line per open stream out of the log.

The handler gets a `*spider.Sse` instead of a `*spider.Ctx`:

```zig from=examples/bookings/src/features/home/controller.zig decl=events,channelOf
```

- `sse.param("day")` is the `:day` of the path. `sse.header(name)` and `sse.cookie(name)` read the request.
- `sse.join(channel)` says what this connection listens to. A channel is a name the app makes up: here one per day, `day:2026-10-12`.
- `sse.wait()` holds the stream open until the browser goes away. When the handler returns, the stream ends: a handler that returns early, as this one does for a path that is not a date, just closes it.

The browser sees the stream open when the handler listens (`join`, `wait`) and not before, so nothing said on the channel after that moment is missed.

## Saying that something changed

Whoever changes a booking tells the channel of its day. From a handler, the hub is `c.sseHub()`:

```zig from=examples/bookings/src/features/home/controller.zig decl=announce
```

`emitTo(channel, event, data)` sends the event to every connection that joined the channel, with `data` as JSON. The handlers that make, confirm or cancel a booking call it once the database has done its part:

```zig from=examples/bookings/src/features/bookings/controller.zig decl=cancel
```

A job has no request, so it is given the hub. This one releases the holds nobody confirmed and tells the days they were on (see [Scheduled jobs](/docs/jobs)):

```zig from=examples/bookings/src/features/bookings/jobs.zig decl=expireHolds
```

This is what a browser on `/events/2033-03-07` receives when a booking of that day is made:

```text
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive

retry: 3000

: heartbeat

id: 6
event: changed
data: {"day":"2033-03-07"}
```

`retry` tells the browser to wait three seconds before connecting again after a drop. The `: heartbeat` line is a comment, which browsers skip: see the end of this page.

## The page, with htmx 4

Bookings uses htmx 4 and its SSE extension (`spider new --htmx=4` sets a project up with both). Two elements of the day view do the work:

```html
<div hx-sse:connect="/events/{ day.day }" hx-swap="none"></div>

<div id="day" hx-get="{ self }" hx-trigger="changed from:body, every 60s" hx-select="#day" hx-swap="outerHTML">
    ...
</div>
```

The first opens the stream of the day on screen. An event with a name becomes an event in the page, so `changed` from the server is a `changed` the second element hears (`from:body`): it asks for the same address again and replaces itself with the new `#day`. `every 60s` is the fallback, and what moves the "now" line.

The event carries no HTML on purpose. Each visitor asks for the page as themselves, so what they get went through the same route, the same access rules and their own session: a booking shows "yours" only to its owner. The alternative is to send the HTML itself, `c.sseHub().emitHtmlTo(channel, "", html)`: a message without a name is what `hx-sse:connect` swaps into its element. That fits when everyone sees the same thing.

## The page, without htmx

The browser's own `EventSource` is enough:

```html
<script>
    const stream = new EventSource("/events/2033-03-07");
    stream.addEventListener("changed", (event) => {
        const data = JSON.parse(event.data);
        console.log("changed:", data.day);
    });
</script>
```

## A test for a stream

The test opens the stream the way a browser does, makes two bookings and reads what arrives: the booking of another day says nothing, the one of this day says `changed`.

```zig from=examples/bookings/src/pages_test.zig decl="the day's stream says \"changed\" when a booking of that day is made, and only then"
```

## More than one channel, and what was missed

- `sse.subscribe(channel)` adds a channel and keeps the ones the connection has; `join` replaces them. A browser opens few connections to one address, so a page that follows several things should use one stream with several channels.
- `sse.joinUser(id)` joins the channel of one account, and `hub.notifyUser(id, event, data)` sends to it.
- `sse.joinWithReplay(channel)`: a browser that connects again says the id of the last event it saw, and this sends what the channel recorded after it (the last 50 events, at most five minutes old).
- `sse.send(event, data)` sends to this one connection, before `wait()`: its first state, for example.

## In production

A proxy between the browser and the app may close a connection that says nothing for a while. `sseHeartbeat` sends a comment line on every stream at an interval, which keeps them open. Bookings turns it on where it makes its server, in `main`: `.sseHeartbeat(null)` is every 30 seconds, and a number is that many milliseconds.

A proxy that buffers responses holds events back: turn buffering off for the stream's path. And a connection that cannot take what is sent to it for `stream_write_timeout_ms` (10 seconds) is dropped, so one slow reader does not hold the others.
