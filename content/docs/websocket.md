---
title: WebSocket
section: guide
order: 160
---

# WebSocket

A WebSocket is a connection both sides write to. Use one when the browser has things to say all the time: a chat, a cursor, a game. When only the server speaks, and the browser listens, [server-sent events](/docs/live) are simpler: they are plain HTTP, and the browser connects again by itself.

The code on this page is from `examples/guide` ([source](https://github.com/llllOllOOll/spiderme/tree/main/examples/guide)): a small server kept as tests, for what the example apps do not use.

## A socket is a route

```zig from=examples/guide/src/server.zig decl=run
```

`wsWith` takes the same config as any route. The handler gets a `*spider.Ws` once the socket is open:

```zig from=examples/guide/src/server.zig decl=chat
```

- `ws.param("room")` is the `:room` of the path.
- `ws.join(channel)` puts the connection on a channel, a name the app makes up. A connection is on one channel at a time.
- `ws.send(text)` writes to this connection only.
- `ws.next()` waits for the next message; `message.data` is what the visitor sent. It gives `null` when the visitor is gone, which ends the loop.
- `ws.broadcastTo(channel, text)` writes to everyone on the channel, the sender included. `ws.broadcast(text)` writes to every connection of the route, whatever their channel.

When the handler returns, the socket closes. A handler that returns an error closes it too, and the error goes to the log.

Each WebSocket route has its own set of connections: a broadcast on `/rooms/:room/chat` never reaches a socket opened on another route.

## The page

The browser has what it needs:

```html
<script>
    const scheme = location.protocol === "https:" ? "wss://" : "ws://";
    const socket = new WebSocket(scheme + location.host + "/rooms/zig/chat");

    socket.addEventListener("message", (event) => {
        console.log("heard:", event.data);
    });

    function say(text) {
        socket.send(text);
    }
</script>
```

Unlike a stream of events, a WebSocket that drops stays closed: a page that has to survive that opens a new one on the `close` event.

## A test for a socket

The test opens three sockets, two in one room and one in another, and checks who hears what. It speaks the protocol by hand, which is a few lines:

```zig from=examples/guide/src/websocket_test.zig decl=Client decl="websocket: what one says, everyone in the same room hears, and nobody else"
```

## Who may open one

The route's config is checked on the request that asks for the socket. A visitor who does not pass gets a 401 or a 403, and no socket:

```zig from=examples/guide/src/websocket_test.zig decl="websocket: a route's access is checked before the socket opens"
```

A page on another site cannot open a socket to your app with the visitor's cookies: the cross-site check of [Security in production](/docs/security) refuses it, and it is on by default.

```zig from=examples/guide/src/websocket_test.zig decl="websocket: a page on another site cannot open one"
```

`ws(path, handler)`, without a config, declares no access: prefer `wsWith`, so that the route says who it is for.

## Good to know

- `ws.joinUser(id)` joins the channel `user:<id>`: `ws.broadcastTo("user:7", text)` then reaches every socket of account 7 on the route.
- `message.data` is kept until the connection ends. A connection that receives a lot for a long time keeps growing in memory: keep messages small, and close sockets that have been open for days.
- A message can have up to 16 MiB. One the browser splits into several frames is not put back together, and ends the connection: browsers send ordinary messages in one frame.
- `wsInterval(path, ms, callback)` is a route whose sockets only listen: the callback gets the route's hub every `ms` milliseconds and sends to them.
- A socket gets its line in the [request log](/docs/logging) when it closes.
