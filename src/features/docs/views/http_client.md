-- doc

# HTTP Client (Pacman)#

Spider includes seamless integration with [pacman](https://github.com/llllOllOOll/pacman), a native Zig HTTP client built on `std.Io` with full async/await support.

## Features#

- `GET`, `POST`, `PUT`, `PATCH`, `DELETE` methods
- JSON body — auto-serialized, zero boilerplate
- Form body with URL encoding
- Query params and URL path params (`:id` → `42`)
- Response headers with case-insensitive lookup
- `Client` with `baseURL` and global headers
- Native `std.Io` — works with `Threaded`, `Evented`, or any backend
- Async/await ready — pass `io` and let the caller decide concurrency
- Arena-based memory — one `res.deinit()` cleans everything

## Installation#

Add to your project's `build.zig.zon`:

```zig
.dependencies = .{
    .pacman = .{
        .url = "https://github.com/llllOllOOll/pacman/archive/main.tar.gz",
        .hash = "...",
    },
};
```

Then in `build.zig`:

```zig
const pacman = b.dependency("pacman", .{});
exe.root_module.addImport("pacman", pacman.module("pacman"));
```

## Basic Usage (Standalone)#

```zig
const pacman = @import("pacman");

// Simple GET request
var res = try pacman.get(io, allocator, "https://api.example.com/users", .{});
defer res.deinit();

std.debug.print("{s}\n", .{res.text()});
```

## GET with Query Parameters#

```zig
var res = try pacman.get(io, allocator, "https://api.example.com/users", .{
    .query = &.{
        .{ "page", "1" },
        .{ "limit", "20" },
    },
});
defer res.deinit();

const users = try std.json.parse(allocator, Users, res.body()) catch break;
```

## POST with JSON Body#

```zig
const payload = .{ .name = "Alice", .age = 25 };

var res = try pacman.post(io, allocator, "https://api.example.com/users", .{
    .json = payload,
});
defer res.deinit();

std.debug.print("Status: {d}\n", .{res.status});
```

## POST with Form Body#

```zig
var res = try pacman.post(io, allocator, "https://api.example.com/login", .{
    .form = &.{
        .{ "username", "alice" },
        .{ "password", "secret" },
    },
});
defer res.deinit();
```

## Custom Headers#

```zig
var client = pacman.Client.init(allocator, io, "https://api.example.com");
defer client.deinit();

client.headers.append(allocator, "Authorization", "Bearer token123") catch {};

var res = try client.get(allocator, "/users", .{});
defer res.deinit();
```

## Async/Await (with std.Io)#

```zig
fn fetchUser(io: std.Io, allocator: std.mem.Allocator, id: []const u8) ![]const u8 {
    var res = try pacman.get(io, allocator, "https://api.example.com/users/", .{});
    defer res.deinit();
    return allocator.dupe(u8, res.text());
}

// Usage with std.Io.Threaded
var threaded = std.Io.Threaded.init(.{});
const io = threaded.io();

const user = try fetchUser(io, allocator, "123");
```
