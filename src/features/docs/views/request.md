-- md
{% extends "layout_docs" %}
{% block "content" %}
# Request

Access route parameters, parse JSON bodies, and read form or query string values directly from `*spider.Request`.

```zig
// Route parameter — /users/:id
const id = req.param("id") orelse return spider.Response.text(alc, "missing id");

// JSON body binding
const Task = struct { title: []const u8, done: bool };
const task = try req.bindJson(alc, Task);

// Form parameter (POST application/x-www-form-urlencoded)
const name = try req.formParam("name", alc);

// Query string (?page=2)
const page = try req.queryParam("page", alc);

// Raw path (e.g. "/users/42")
const path = req.path;
```

## External HTTP Client with Pacman

Spider includes seamless integration with [pacman](https://github.com/llllOllOOll/pacman), a native Zig HTTP client built on `std.Io` with full async/await support.

### Features

- `GET`, `POST`, `PUT`, `PATCH`, `DELETE` methods
- JSON body — auto-serialized, zero boilerplate
- Form body with URL encoding
- Query params and URL path params (`:id` → `42`)
- Response headers with case-insensitive lookup
- `Client` with `baseURL` and global headers
- Native `std.Io` — works with `Threaded`, `Evented`, or any backend
- Async/await ready — pass `io` and let the caller decide concurrency
- Arena-based memory — one `res.deinit()` cleans everything

### Installation

Add to your project's `build.zig.zon`:

```zig
.dependencies = .{
    .pacman = .{
        .url = "https://github.com/llllOllOOll/pacman/archive/main.tar.gz",
        .hash = "...",
    },
},
```

Then in `build.zig`:

```zig
const pacman = b.dependency("pacman", .{});
exe.root_module.addImport("pacman", pacman.module("pacman"));
```

### Basic Usage (Standalone)

```zig
const pacman = @import("pacman");

// Simple GET request
var res = try pacman.get(io, allocator, "https://api.example.com/users", .{});
defer res.deinit();

std.debug.print("{s}\n", .{res.text()});
```

#### GET with Query Parameters

```zig
var res = try pacman.get(io, allocator, "https://api.example.com/users", .{
    .query = &.{
        .{ "page", "1" },
        .{ "limit", "20" },
        .{ "search", "hello world" }, // automatically URL-encoded
    },
});
defer res.deinit();
// → GET /users?page=1&limit=20&search=hello%20world
```

#### POST with JSON Body

```zig
const payload = .{ .name = "seven", .role = "admin" };
const serialized = try std.json.Stringify.valueAlloc(allocator, payload, .{});
defer allocator.free(serialized);

var res = try pacman.post(io, allocator, "https://api.example.com/users", .{
    .body = pacman.jsonBody(serialized),
});
defer res.deinit();
```

#### Client with BaseURL and Headers

```zig
var api = pacman.Client.init(io, allocator, .{
    .base_url = "https://api.example.com",
    .headers = &.{
        .{ .name = "Authorization", .value = "Bearer your-token" },
        .{ .name = "Accept", .value = "application/json" },
    },
});

var res = try api.get("/users", .{});
defer res.deinit();
```

### Integration with Spider Handlers

Use pacman within Spider handlers to call external APIs:

```zig
fn getUserWithExternalData(alc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    const pacman = @import("pacman");
    
    // Get user from database
    const id = req.param("id") orelse return spider.Response.text(alc, "missing id");
    const user = try db.queryOne(User, alc, "SELECT * FROM users WHERE id = $1", .{id});
    
    // Fetch external data
    var external_res = try pacman.get(io, alc, "https://api.example.com/user/" + user.id, .{});
    defer external_res.deinit();
    
    const external_data = external_res.text();
    
    return spider.Response.json(alc, .{
        .user = user,
        .external_data = external_data,
    });
}
```

#### Concurrent External API Calls

```zig
fn getDashboardData(alc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    const pacman = @import("pacman");
    
    // Start multiple requests in parallel
    var user_future = io.async(pacman.get, .{io, alc, "https://api.example.com/user", .{}});
    var posts_future = io.async(pacman.get, .{io, alc, "https://api.example.com/posts", .{}});
    
    // Await both
    var user_res = try user_future.await(io);
    defer user_res.deinit();
    
    var posts_res = try posts_future.await(io);
    defer posts_res.deinit();
    
    return spider.Response.json(alc, .{
        .user = user_res.text(),
        .posts = posts_res.text(),
    });
}
```

### Reading Responses

```zig
var res = try pacman.get(io, allocator, "https://api.example.com/users/42", .{});
defer res.deinit();

// Status code
std.debug.print("status: {d}\n", .{res.status});

// Body as string
const body = res.text();

// Body as JSON
const User = struct { id: u32, name: []const u8 };
const parsed = try res.json(User);
std.debug.print("name: {s}\n", .{parsed.value.name});

// Response headers (case-insensitive)
const ct = res.headers.get("content-type");
```

### Form Body

```zig
var res = try pacman.post(io, allocator, "https://api.example.com/login", .{
    .body = .{ .form = &.{
        .{ "username", "seven" },
        .{ "password", "secret" },
    }},
});
defer res.deinit();
```

### Async/Await Patterns

pacman is built on `std.Io` — the same interface that powers Zig's async I/O.

#### Two Requests in Parallel

```zig
var t1 = io.async(pacman.get, .{ io, allocator, "https://api.example.com/users", .{} });
var t2 = io.async(pacman.get, .{ io, allocator, "https://api.example.com/posts", .{} });

var r1 = try t1.await(io);
defer r1.deinit();

var r2 = try t2.await(io);
defer r2.deinit();
```

#### Safe Cancellation

```zig
var task = io.async(pacman.get, .{ io, allocator, url, .{} });
defer task.cancel(io) catch {};

var res = try task.await(io);
defer res.deinit();
```

### API Reference

#### Standalone Functions

| Function | Description |
|---|---|
| `get(io, allocator, url, opts)` | HTTP GET |
| `post(io, allocator, url, opts)` | HTTP POST |
| `put(io, allocator, url, opts)` | HTTP PUT |
| `patch(io, allocator, url, opts)` | HTTP PATCH |
| `delete(io, allocator, url, opts)` | HTTP DELETE |
| `jsonBody(serialized)` | Wraps a serialized JSON string as a `Body` |

#### FetchOptions

| Field | Type | Default | Description |
|---|---|---|---|
| `headers` | `[]const http.Header` | `&.{}` | Request headers |
| `body` | `?Body` | `null` | Request body |
| `query` | `[]const [2][]const u8` | `&.{}` | Query params |
| `params` | `[]const [2][]const u8` | `&.{}` | URL path params |
| `timeout_ms` | `u32` | `0` | Timeout in ms (0 = none) |

#### Response Methods

| Method | Description |
|---|---|
| `res.status` | HTTP status (`.ok`, `.not_found`, etc.) |
| `res.text()` | Body as `[]const u8` |
| `res.json(T)` | Body parsed as `std.json.Parsed(T)` |
| `res.headers.get(name)` | Header value by name (case-insensitive) |
| `res.deinit()` | Frees all memory — arena-based |

#### Client Methods

| Method | Description |
|---|---|
| `Client.init(io, allocator, opts)` | Create configured client |
| `client.get(path, opts)` | GET with baseURL prepended |
| `client.post(path, opts)` | POST with baseURL prepended |
| `client.put(path, opts)` | PUT with baseURL prepended |
| `client.patch(path, opts)` | PATCH with baseURL prepended |
| `client.delete(path, opts)` | DELETE with baseURL prepended |

## Memory & Allocator

Every handler receives an `alc: std.mem.Allocator` as its first parameter. This allocator is a per-request arena created by Spider before dispatching the request and destroyed automatically after the response is sent.

```zig
// Handler signature: (allocator, request) -> Response
fn getUser(alc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    // Use alc directly — it's a per-request arena
    const user = try db.queryOne(User, alc, "SELECT * FROM users WHERE id = $1", .{id});
    return spider.Response.json(alc, user);
}
```

### Lifetime

The arena lives from the start of the request until the response is fully written. Any memory allocated with `alc` is freed automatically — no `defer` needed inside the handler.

### Do not create nested arenas

There is no reason to wrap `alc` in another `ArenaAllocator` inside a handler:

```zig
// ❌ unnecessary — alc is already a per-request arena
fn getUser(alc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    var arena = std.heap.ArenaAllocator.init(alc);
    defer arena.deinit();
    const user = try db.queryOne(User, arena.allocator(), ...);
    ...
}

// ✅ correct — use alc directly
fn getUser(alc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    const id = req.param("id") orelse return spider.Response.text(alc, "not found");
    const user = try db.queryOne(User, alc, "SELECT * FROM users WHERE id = $1", .{id});
    return spider.Response.json(alc, user);
}
```

**Implementation:** Spider creates and owns the arena — handlers never need to free it, even if an error is returned.
{% end %}
