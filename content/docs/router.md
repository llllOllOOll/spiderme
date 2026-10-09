---
title: Routing
section: guide
order: 10
---

# Routing

Chain routes on the server. Paths are matched with a trie, and a segment that starts with a colon matches any value.

```zig
server
    .get("/", home, .{ .public = true })
    .get("/users/:id", showUser, .{ .public = true })
    .listen(.{}) catch {};
```

Every route takes three arguments: the path, the handler, and a config that says who may call it. An empty config, `.{}`, is allowed.

## Dynamic segments

A segment that starts with a colon matches any value at that position and gives it to the handler.

```zig
fn showUser(c: *spider.Ctx) !spider.Response {
    const id = c.params.get("id") orelse return error.NotFound;
    return c.text(id, .{});
}
```

## Groups

Routes that share a prefix live in a group, usually one per feature.

```zig
pub fn build() spider.Group {
    var g = spider.Group.init("/posts");
    _ = g.get("/", list, .{ .public = true });
    _ = g.get("/:id", show, .{ .public = true });
    return g;
}
```
