-- md
{% extends "layout_docs" %}
{% block "content" %}
# PostgreSQL with Spider

Spider has a built-in PostgreSQL client via `spider.pg`. This guide covers everything from basic queries to transactions with automatic logging.

## Why PostgreSQL with Zig?

- **Performance**: Native speed with minimal overhead
- **Type Safety**: Full Zig type safety for database operations
- **Connection Pooling**: Built-in connection pool with health checks
- **Easy API**: Simple query API with automatic mapping

## Live Example

See the full working example on GitHub:

[https://github.com/llllOllOOll/spider-postgres](https://github.com/llllOllOOll/spider-postgres)

This example includes:
- Complete CRUD API with bands
- 50 Brazilian metal bands from Bahia
- Docker Compose setup
- .env configuration

## Prerequisites

The PostgreSQL client library (`libpq`) must be installed on your system.

On Arch Linux:

```bash
pacman -S postgresql-libs
```

Verify the installation:

```bash
pkg-config --exists libpq && echo "ok"
```

For other distributions (Debian, Ubuntu, Fedora, etc.) install the equivalent package — usually `libpq-dev` or `postgresql-devel`.

## Start PostgreSQL

We'll use Docker to run PostgreSQL locally. Create a `docker-compose.yml`:

```yaml
services:
  db:
    container_name: spider_db
    image: postgres:17
    environment:
      POSTGRES_USER: spider
      POSTGRES_PASSWORD: spider
      POSTGRES_DB: spider_db
    ports:
      - "5433:5432"
```

```bash
docker compose up -d
```

Connect and create a table:

```bash
docker exec -it spider_db psql -U spider -d spider_db
```

```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL,
  active BOOLEAN DEFAULT true
);

INSERT INTO users (email, name, active) VALUES
  ('alice@example.com', 'Alice Smith', true),
  ('bob@example.com', 'Bob Jones', false);
```

## Configure build.zig

Add `link_libc` for the executable. Spider handles `libpq` linking automatically:

```zig
const exe = b.addExecutable(.{
    .name = "myapp",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true, // required for libc functions
        .imports = &.{
            .{ .name = "spider", .module = spider_dep.module("spider") },
        },
    }),
});
// Spider automatically links libpq — no need to add linkSystemLibrary!
```

## Connect and query

Define a struct that matches your table columns. The API returns arrays directly:

```zig
const db = spider.pg;

const User = struct {
    id: i64,
    email: []const u8,
    name: []const u8,
    active: bool,
};

fn usersHandler(arena: std.mem.Allocator, _: *spider.Request) !spider.Response {
    // Spider passes arena automatically — use it directly!
    const users = try db.query(User, arena,
        "SELECT id, email, name, active FROM users ORDER BY id", .{});

    return spider.Response.json(arena, users);
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    try db.init(arena, io, .{});
    defer db.deinit();

    const server = try spider.Spider.init(arena, io, "127.0.0.1", 8080);
    defer server.deinit();

    server.get("/users", usersHandler)
        .listen() catch |err| return err;
}
```

## Query Parameters

Pass parameters using a struct literal with named fields. Spider handles type conversion automatically:

```zig
// Filter by active status
const users = try db.query(User, arena,
    "SELECT id, email, name FROM users WHERE active = $1",
    .{ .active = true });

// INSERT with RETURNING
const result = try db.query(struct { id: i64 }, arena,
    "INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id",
    .{ .email = "alice@test.com", .name = "Alice" });
const new_id = result[0].id;
```

Supported parameter types: `i32`, `i64`, `f32`, `f64`, `bool`, `[]const u8`, and optionals.

## INSERT / UPDATE / DELETE

Use `db.query(void, arena, sql, params)` for mutations:

```zig
// INSERT with RETURNING
const result = try db.query(struct { id: i64 }, arena,
    "INSERT INTO bands (name) VALUES ($1) RETURNING id", .{ .name = "New Band" });

// UPDATE
try db.query(void, arena,
    "UPDATE bands SET name = $1 WHERE id = $2", .{ .name = "Updated", .id = 1 });

// DELETE
try db.query(void, arena,
    "DELETE FROM bands WHERE id = $1", .{ .id = 1 });
```

## Transactions

Use `db.begin()` to start a transaction. Always defer `rollback()` for automatic cleanup on error:

```zig
pub fn createBulk(inputs: []const CreateInput) !usize {
    var tx = try db.begin();
    defer tx.rollback();

    var arena = std.heap.ArenaAllocator.init(init.arena.allocator());
    defer arena.deinit();

    var inserted: usize = 0;
    for (inputs) |input| {
        try tx.query(void, arena.allocator(),
            "INSERT INTO items (name, price) VALUES ($1, $2)",
            .{ .name = input.name, .price = input.price });
        inserted += 1;
    }

    // Commit only if all inserts succeeded
    try tx.commit();
    return inserted;
}
```

> **Transaction pattern:** `defer tx.rollback()` ensures the transaction is rolled back if any query fails. Only call `commit()` when everything succeeds.

## Query Logging

Spider automatically logs every query with timing and parameters — no setup required:

```bash
# INFO level: SQL, row count, execution time
pg: SELECT * FROM users WHERE id = $1 (1 rows, 123µs)

# DEBUG level: SQL with parameter values
pg: $1 = "42"
```

- **INFO level:** SQL query, number of rows returned, execution time in microseconds
- **DEBUG level:** Parameter values as readable `$1 = "value"` format

### Controlling Log Level

Use `LOG_LEVEL` environment variable to control logging verbosity:

```bash
# Development — see all queries with params
export LOG_LEVEL=debug

# Production — hide pg logs, show only warnings/errors
export LOG_LEVEL=warn
```

Available levels: `err`, `warn`, `info`, `debug`

## Using .env

Move credentials to a `.env` file for production. Spider reads them automatically:

```bash
# .env
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=spider
POSTGRES_PASSWORD=spider
POSTGRES_DB=spider_db
```

```zig
// Load .env (silently skips if not found)
spider.loadEnv(arena, ".env") catch {};

// Initialize — reads POSTGRES_* from .env or environment
try db.init(arena, io, .{});
```

> **Note:** Add `.env` to your `.gitignore` — never commit credentials.

## API Reference

```zig
// Initialize
const db = spider.pg;
try db.init(arena, io, .{});
defer db.deinit();

// SELECT multiple rows — returns []T directly
const bands = try db.query(Band, arena, "SELECT * FROM bands", .{});

// INSERT with RETURNING
const result = try db.query(struct { id: i64 }, arena,
    "INSERT INTO bands (name) VALUES ($1) RETURNING id", .{ .name = "Band" });
const new_id = result[0].id;

// UPDATE/DELETE
try db.query(void, arena,
    "DELETE FROM bands WHERE id = $1", .{ .id = 1 });

// Transactions
var tx = try db.begin();
defer tx.rollback();
try tx.query(void, arena, "INSERT...", .{});
try tx.commit();
```

### Driver Details

Spider uses the official PostgreSQL C library (`libpq`) via FFI:

- **Location**: `src/pg.zig` (~2400 lines)
- **API**: 100% Zig with native types
- **Backend**: libpq (official PostgreSQL client)

#### Connection Pooling

- **Default pool size**: 10 connections
- **Configurable**: via `.pool_size` in `db.init()`
- **Automatic health check**: validates connection before use
- **Thread-safe**: connections checked out/in atomically

#### Supported Types

| Zig Type | PostgreSQL Type |
|----------|----------------|
| `i32` | INTEGER |
| `i64` | BIGINT |
| `f32` | REAL |
| `f64` | DOUBLE PRECISION |
| `bool` | BOOLEAN |
| `[]const u8` | TEXT / VARCHAR |
| `?i32` | INTEGER (nullable) |


## API Reference

### Core

| Function | Returns | Description |
|----------|---------|-------------|
| `db.init(arena, io, config)` | `!void` | Initialize connection pool |
| `db.deinit()` | `void` | Close all connections |

### Query

| Function | Returns | Description |
|----------|---------|-------------|
| `db.query(T, arena, sql, params)` | `![]T` | SELECT — returns slice of T |
| `db.query(void, arena, sql, params)` | `!void` | INSERT / UPDATE / DELETE |
| `db.query(i32, arena, sql, params)` | `!i32` | INSERT RETURNING id |
| `db.queryOne(T, arena, sql, params)` | `!?T` | SELECT single row, null if not found |
| `db.queryExecute(T, arena, sql)` | `![]T` | Raw SQL, no params, multiple statements |
| `db.queryOneExecute(T, arena, sql)` | `!?T` | Raw SQL single row, no params |

### Transaction

| Function | Returns | Description |
|----------|---------|-------------|
| `db.begin()` | `!Transaction` | Start transaction |
| `tx.query(T, arena, sql, params)` | `![]T` / `!void` / `!i32` | Same as `db.query` on transaction connection |
| `tx.queryOne(T, arena, sql, params)` | `!?T` | Same as `db.queryOne` on transaction connection |
| `tx.commit()` | `!void` | Commit — error if already finished |
| `tx.rollback()` | `void` | Rollback — no-op if already committed |

### Config

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `.host` | `[]const u8` | `"localhost"` | Database host |
| `.port` | `u16` | `5432` | Database port |
| `.user` | `[]const u8` | `""` | Database user |
| `.password` | `[]const u8` | `""` | Database password |
| `.database` | `[]const u8` | `""` | Database name |
| `.pool_size` | `usize` | `10` | Connection pool size |

> **Note:** `db.query` and `db.queryOne` support parameterized queries — safe against SQL injection. `db.queryExecute` and `db.queryOneExecute` use raw SQL without parameters — never use with user input.

{% end %}
