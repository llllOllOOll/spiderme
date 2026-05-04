-- doc

# PostgreSQL

Spider includes a native PostgreSQL driver (`spider.pg`) built on the wire protocol — no libpq needed. Uses a connection pool with retry logic (5 attempts, exponential backoff) and supports parameterized queries (`$1`, `$2`, ...).

## Quick Start

```zig
const std = @import("std");
const spider = @import("spider");
const db = spider.pg;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    try db.init(arena, init.io, .{
        .host = spider.env.getOr("PG_HOST", "localhost"),
        .port = spider.env.getInt(u16, "PG_PORT", 5432),
        .user = spider.env.getOr("PG_USER", "spider"),
        .password = spider.env.getOr("PG_PASSWORD", "spider"),
        .database = spider.env.getOr("PG_DB", "myapp"),
    });
    defer db.deinit();

    var server = spider.app();
    defer server.deinit();

    server
    .get("/users", listUsers)
    .listen(.{ .port = 3000 }) catch {};
}
```

## Query with struct mapping

`db.query(T, arena, sql, params)` returns `[]T` for structs, `i32` for counts, `void` for INSERT/UPDATE/DELETE.

```zig
const User = struct { id: i32, name: []const u8, email: []const u8 };

pub fn listUsers(c: *spider.Ctx) !spider.Response {
    const users = try db.query(User, c.arena,
        "SELECT id, name, email FROM users WHERE active = $1",
        .{true},
    );
    return c.json(users, .{});
}
```

## Query a single row

`db.queryOne(T, arena, sql, params)` returns `?T`.

```zig
pub fn getUser(c: *spider.Ctx) !spider.Response {
    const id = try std.fmt.parseInt(i32, c.param("id") orelse "0", 10);
    const user = try db.queryOne(User, c.arena,
        "SELECT id, name, email FROM users WHERE id = $1",
        .{id},
    ) orelse return c.json(.{ .error = "not found" }, .{ .status = .not_found });
    return c.json(user, .{});
}
```

## INSERT with RETURNING

```zig
pub fn createUser(c: *spider.Ctx) !spider.Response {
    const Input = struct { name: []const u8, email: []const u8 };
    const input = try c.bodyJson(Input);
    try db.query(void, c.arena,
        "INSERT INTO users (name, email) VALUES ($1, $2)",
        .{ input.name, input.email },
    );
    return c.json(.{ .created = true }, .{ .status = .created });
}
```

## INSERT/UPDATE/DELETE

```zig
pub fn updateUser(c: *spider.Ctx) !spider.Response {
    const id = try std.fmt.parseInt(i32, c.param("id") orelse "0", 10);
    try db.query(void, c.arena,
        "UPDATE users SET name = $1 WHERE id = $2",
        .{ "New Name", id },
    );
    return c.redirect("/users");
}
```

## COUNT — returns i32

```zig
pub fn countUsers(c: *spider.Ctx) !spider.Response {
    const count = try db.query(i32, c.arena, "SELECT COUNT(*) FROM users", .{});
    return c.json(.{ .count = count }, .{});
}
```

## Array parameters (ANY)

```zig
pub fn batchUsers(c: *spider.Ctx) !spider.Response {
    const ids = [_]i32{ 1, 2, 3 };
    const rows = try db.query(User, c.arena,
        "SELECT id, name, email FROM users WHERE id = ANY($1)",
        .{db.array(i32, &ids)},
    );
    return c.json(rows, .{});
}
```

## Transactions

```zig
pub fn transferHandler(c: *spider.Ctx) !spider.Response {
    var tx = try db.begin();
    defer tx.rollback();

    try tx.query(void, c.arena, "UPDATE accounts SET balance = balance - $1 WHERE id = $2", .{ amount, from_id });
    try tx.query(void, c.arena, "UPDATE accounts SET balance = balance + $1 WHERE id = $2", .{ amount, to_id });
    try tx.commit();

    return c.json(.{ .ok = true }, .{});
}
```

## Migrations (multi-statement)

Use `db.queryExecute(T, arena, sql)` for raw SQL without parameters. Supports multiple statements separated by `;`.

```zig
try db.queryExecute(void, c.arena,
    "CREATE TABLE IF NOT EXISTS users (" ++
    "  id SERIAL PRIMARY KEY, name TEXT, email TEXT UNIQUE" ++
    ");" ++
    "CREATE TABLE IF NOT EXISTS posts (" ++
    "  id SERIAL PRIMARY KEY, title TEXT, user_id INTEGER REFERENCES users(id)" ++
    ");"
);
```

## Full example

```zig
const std = @import("std");
const spider = @import("spider");
const db = spider.pg;

const User = struct { id: i32, name: []const u8, email: []const u8 };

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    try db.init(arena, init.io, .{});
    defer db.deinit();

    var server = spider.app();
    defer server.deinit();

    server
    .get("/users", listUsers)
    .get("/users/:id", getUser)
    .listen(.{ .port = 3000 }) catch {};
}

fn listUsers(c: *spider.Ctx) !spider.Response {
    const users = try db.query(User, c.arena, "SELECT id, name, email FROM users", .{});
    return c.json(users, .{});
}

fn getUser(c: *spider.Ctx) !spider.Response {
    const id = try std.fmt.parseInt(i32, c.param("id") orelse "0", 10);
    const user = try db.queryOne(User, c.arena,
        "SELECT id, name, email FROM users WHERE id = $1",
        .{id},
    ) orelse return c.json(.{ .error = "not found" }, .{ .status = .not_found });
    return c.json(user, .{});
}
```

## API Reference

| Method | Description |
|--------|-------------|
| `db.init(allocator, io, config)` | Initialize pool (DbConfig with optional overrides) |
| `db.deinit()` | Shutdown pool |
| `db.query(T, arena, sql, params)` | Parameterized query → `[]T`, `i32`, or `void` |
| `db.queryOne(T, arena, sql, params)` | Parameterized query → `?T` (single row) |
| `db.queryExecute(T, arena, sql)` | Raw SQL without params (multi-statement with `;`) |
| `db.queryOneExecute(T, arena, sql)` | Raw SQL single row without params |
| `db.array(T, values)` | Create array param for `ANY($1)` |
| `db.begin()` | Start transaction → `Transaction` |
| `db.Transaction.query(T, arena, sql, params)` | Query inside transaction |
| `db.Transaction.queryOne(T, arena, sql, params)` | Single row inside transaction |
| `db.Transaction.commit()` | Commit transaction |
| `db.Transaction.rollback()` | Rollback transaction |
