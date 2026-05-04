-- doc

# PostgreSQL

Spider includes a native PostgreSQL driver (`spider.pg`) built on the wire protocol — no libpq needed.

## Quick Start

```zig
const spider = @import("spider");
const pg = spider.pg;

pub fn main(init: std.process.Init) !void {
    try pg.init(init.arena, init.io, .{
        .host = "localhost",
        .port = 5432,
        .user = "spider",
        .password = "spider",
        .database = "myapp",
        .pool_size = 10,
    });
    defer pg.deinit();

    var server = spider.app();
    defer server.deinit();

    server.db(spider.pg.PgDriver.database());

    server
        .get("/users", listUsers)
        .listen(3000) catch {};
}
```

## Query with struct mapping

```zig
const User = struct { id: i32, name: []const u8, email: []const u8 };

pub fn listUsers(c: *spider.Ctx) !spider.Response {
    const users = try c.db().query(User, "SELECT id, name, email FROM users", .{});
    return c.json(users, .{});
}
```

## Query a single row

```zig
pub fn getUser(c: *spider.Ctx) !spider.Response {
    const id = try std.fmt.parseInt(i32, c.param("id") orelse "", 10);
    const user = try c.db().queryOne(User, "SELECT * FROM users WHERE id = $1", .{id});
    if (user) |u| return c.json(u, .{}) else return c.text("Not found", .{ .status = .not_found });
}
```

## INSERT with RETURNING

```zig
pub fn createUser(c: *spider.Ctx) !spider.Response {
    const input = try c.parseForm(struct { name: []const u8, email: []const u8 });
    const new_id = try c.db().query(i32, "INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id", .{input.name, input.email});
    return c.json(.{ .id = new_id }, .{ .status = .created });
}
```

## INSERT/UPDATE/DELETE

```zig
pub fn updateUser(c: *spider.Ctx) !spider.Response {
    const id = try std.fmt.parseInt(i32, c.param("id") orelse "", 10);
    _ = try c.db().query(void, "UPDATE users SET name = $1 WHERE id = $2", .{"New Name", id});
    return c.redirect("/users");
}
```

## Array parameters (ANY)

```zig
const ids = [_]i32{ 1, 2, 3 };
const users = try c.db().query(User, "SELECT * FROM users WHERE id = ANY($1)", .{spider.pg.array(i32, &ids)});
```

## Migrations (multi-statement)

```zig
_ = try c.db().query(void,
    "CREATE TABLE IF NOT EXISTS users (" ++
    "  id SERIAL PRIMARY KEY, name TEXT, email TEXT UNIQUE" ++
    ");" ++
    "CREATE TABLE IF NOT EXISTS posts (" ++
    "  id SERIAL PRIMARY KEY, title TEXT, user_id INTEGER REFERENCES users(id)" ++
    ");", .{},
);
```

## Full example

```zig
const std = @import("std");
const spider = @import("spider");
const pg = spider.pg;

const User = struct { id: i32, name: []const u8, email: []const u8 };

pub fn main(init: std.process.Init) !void {
    try pg.init(init.arena, init.io, .{});
    defer pg.deinit();

    var server = spider.app();
    defer server.deinit();
    server.db(spider.pg.PgDriver.database());

    server
        .get("/users", listUsers)
        .get("/users/:id", getUser)
        .listen(3000) catch {};
}

fn listUsers(c: *spider.Ctx) !spider.Response {
    const users = try c.db().query(User, "SELECT id, name, email FROM users", .{});
    return c.json(users, .{});
}

fn getUser(c: *spider.Ctx) !spider.Response {
    const id = try std.fmt.parseInt(i32, c.param("id") orelse "", 10);
    const user = try c.db().queryOne(User, "SELECT * FROM users WHERE id = $1", .{id});
    if (user) |u| return c.json(u, .{}) else return c.text("Not found", .{ .status = .not_found });
}
```
