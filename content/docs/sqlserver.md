---
title: SQL Server
section: guide
order: 75
---

# SQL Server

`spider.mssql` talks to Microsoft SQL Server: 2012 and later, and Azure SQL. It is written in Zig, speaks SQL Server's own protocol (TDS 7.4) and gets TLS from Zig's standard library: there is no driver or C library to install. Its calls are those of [PostgreSQL](/docs/postgres): `query`, `queryOne`, `queryExecute`, `begin`.

## Turning it on

It is an [optional part](/docs/build#Optional-parts): one line on the Spider dependency in `build.zig`.

```zig
const spider_dep = b.dependency("spider", .{
    .target = target,
    .optimize = optimize,
    .mssql = true,
});
```

Then start the connection pool once, before the server listens, as `src/main.zig` does for any database:

```zig
pub fn serve(allocator: std.mem.Allocator, io: std.Io) !void {
    try spider.mssql.init(allocator, io, .{});
    defer spider.mssql.deinit();

    var server = spider.app(.{});
    defer server.deinit();
    // ...
}
```

## Where the server is

Each field left out of `init` is read from the environment (or `.env`):

| Variable | Without it |
|---|---|
| `MSSQL_HOST` | `localhost` |
| `MSSQL_PORT` | `1433` |
| `MSSQL_DB` | `master` |
| `MSSQL_USER` | `sa` |
| `MSSQL_PASSWORD` | empty |
| `MSSQL_POOL_SIZE` | `10` connections |
| `MSSQL_ENCRYPT` | `true` |
| `MSSQL_TRUST_SERVER_CERTIFICATE` | `false` |

With `MSSQL_ENCRYPT` on, the connection uses TLS, and the server's certificate must chain to a root the system trusts and name the host. A server with a self-signed certificate, as the Docker image and most servers installed on a company's own machines have, needs `MSSQL_TRUST_SERVER_CERTIFICATE=true`. `MSSQL_CERTIFICATE_HOST` names the host the certificate is for, when it is not the one connected to.

A SQL Server to try it on, in Docker:

```bash
docker run -d --name mssql -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD='Spider_Test_1' \
  -p 1433:1433 mcr.microsoft.com/mssql/server:2022-latest
```

It takes about fifteen seconds to accept logins. Then `MSSQL_PASSWORD=Spider_Test_1` and `MSSQL_TRUST_SERVER_CERTIFICATE=true` in `.env`.

## Reading rows

Rows come as structs. A field takes the column of its name, exactly or else ignoring case:

```zig
const Row = struct { n: i64, name: []const u8 };

fn objects(c: *spider.Ctx) !spider.Response {
    const rows = try spider.mssql.query(Row, c.arena,
        "SELECT TOP 20 CAST(object_id AS bigint) AS n, name FROM sys.objects WHERE object_id > @p1 ORDER BY object_id",
        .{@as(i64, 0)});
    return c.json(.{ .count = rows.len, .first = rows[0].name }, .{});
}
```

- Parameters are `@p1`, `@p2`, ... in the SQL and a tuple in the last argument. They are sent apart from the SQL, never pasted into it.
- `query` gives a slice of rows; with `i64` as the type, the first column of the first row.
- `queryOne` gives the first row or `null`.
- A `[]const u8` field takes a column of any type: a date arrives as ISO 8601 text.
- `queryExecute(void, arena, sql)` runs SQL with no parameters, such as a script that creates tables. It is cut into batches at lines holding only `GO`, as `sqlcmd` does, and stops at the first batch that fails.

## Transactions and errors

`begin()` starts a transaction, with `commit` and `rollback`; a second call does nothing, so `defer tx.rollback()` is safe. Sessions run with `XACT_ABORT ON`: an error inside a transaction rolls all of it back.

A failed statement is an error with the name PostgreSQL's would have: `UniqueViolation` for a duplicate key, `ForeignKeyViolation` and `CheckViolation`, `NotNullViolation`, `StringDataRightTruncation`, `DivisionByZero`, `UndefinedTable`, and `RaisedException` for a `THROW` or `RAISERROR` of 50000 and up. So the [error handler](/docs/response) answers 409, 400 or 422 for them, as for PostgreSQL. `spider.mssql.lastError()` has the server's number, class and message.

## Not there yet

- Migrations: the [migration engine](/docs/migrations) is for PostgreSQL and SQLite.
- Retrying on a pooled connection the server closed while it sat idle. After the server restarts, the first query on each old connection fails and the next one reconnects.
- Timeouts and cancelling a running query, and `OUTPUT` parameters.
- `spider new` has no SQL Server template: start with `--no-db` and add the two pieces above.
