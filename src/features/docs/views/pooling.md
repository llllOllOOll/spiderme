-- doc

# Pooling

Spider manages the PostgreSQL connection pool internally via `spider.pg`. The pool is configured at init and all query/exec functions handle acquire/release automatically.

## Configuration

```zig
const spider = @import("spider");
const pg = spider.pg;

try pg.init(allocator, io, .{
    .host = "localhost",
    .port = 5432,
    .user = "spider",
    .password = "spider",
    .database = "myapp",
    .pool_size = 20,   // default: 10
});
```

## Auto-managed

`query()` and `queryOne()` acquire and release automatically — no manual handling:

```zig
pub fn listUsers(c: *spider.Ctx) !spider.Response {
    // Acquires connection, runs query, releases connection
    const users = try c.db().query(User, "SELECT * FROM users", .{});
    return c.json(users, .{});
}
```

## Retry logic

Connections retry up to 5 times with exponential backoff (1s, 2s, 4s, 8s, 16s) before failing.

## Env vars

```
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=spider
POSTGRES_PASSWORD=spider
POSTGRES_DB=myapp
```
