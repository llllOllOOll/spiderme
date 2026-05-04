-- doc

# WebSocket

Spider provides built-in WebSocket support with hub broadcasting via `spider.websocket` and `spider.Hub`.

## Basic WebSocket handler

```zig
const spider = @import("spider");
const websocket = spider.websocket;
const Hub = spider.Hub;

fn wsHandler(c: *spider.Ctx) !spider.Response {
    var ws = websocket.Server.init(c._stream, c._io, c.arena);
    const upgraded = try ws.handshake(c.arena, &c._headers);
    if (!upgraded) return c.text("", .{});

    while (true) {
        const frame = ws.readFrame(c.arena) catch break orelse break;
        switch (frame.opcode) {
            .text => try ws.sendText(frame.payload),
            .close => break,
            .ping => {}, // auto-responded with pong
            else => {},
        }
    }
    return c.text("", .{});
}
```

Register the route:

```zig
server.get("/ws", wsHandler);
```

## Hub broadcasting

Use `spider.getWsHub()` for broadcasting messages to all connected clients:

```zig
fn broadcastHandler(c: *spider.Ctx) !spider.Response {
    const hub = spider.getWsHub();
    try hub.broadcast(c.arena, "New message!");
    return c.json(.{ .ok = true }, .{});
}
```

## Live Reload (dev only)

In development mode, Spider automatically:
- Registers `/_spider/reload` WebSocket endpoint
- Injects script before `</body>` in HTML responses
- Browser reconnects after server restart → `location.reload()`

```bash
watchexec -r -e zig,html,css -- zig build run
```
