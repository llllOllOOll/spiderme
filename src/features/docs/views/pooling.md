-- md
{% extends "layout_docs" %}
{% block "content" %}
# Pooling

Spider manages the PostgreSQL connection pool internally via `spider.pg`. No manual acquire/release needed — `query()`, `queryParams()`, and `exec()` handle it automatically. The pool size defaults to 10.

```zig
// Pool is invisible — Spider manages acquire/release internally
var result = try db.query("SELECT ..."); // acquires connection
defer result.deinit(); // releases connection

// Configure pool size via DbConfig
try spg.init(allocator, io, .{
    .host = "localhost",
    .database = "spider_db",
    .pool_size = 20, // default: 10
});

// Low-level API — for advanced use cases
const pool = spg.Pool;
const conn = try pool.acquire();
defer pool.release(conn);
var result = try spg.queryConn(conn, "SELECT ...");
```
{% end %}
