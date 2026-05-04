-- doc

# Testing#

Spider handlers are plain Zig functions — easy to test with `std.testing`.

## Basic Test#

```zig
const std = @import("std");
const spider = @import("spider");

fn helloHandler(c: *spider.Ctx) !spider.Response {
    return c.text("Hello, {s}!", .{});
}

test "handler returns correct text" {
    const allocator = std.testing.allocator;
    defer std.testing.expectAlloc(allocator);
    
    // Create mock context...
    // (simplified - actual mock setup needed)
    // const c = ...
    // const res = try helloHandler(&c);
    // try std.testing.expectEqual(res.status, .ok);
}
```

## Integration Test#

Use `pacman` (HTTP client) for full integration tests:

```zig
const pacman = @import("pacman");

test "GET / returns 200" {
    // Start server in test mode...
    var res = try pacman.get(io, allocator, "http://localhost:8080/", .{});
    defer res.deinit();
    
    try std.testing.expectEqual(res.status, 200);
    try std.testing.expect(std.mem.eql(u8, res.text(), "expected"));
}
```

## Test Helpers#

Create helpers for common test patterns:

```zig
fn makeRequest(allocator: std.mem.Allocator, method: []const u8, path: []const u8) ![]const u8 {
    // Mock request creation...
    return response;
}

test "POST /users creates user" {
    const res = try makeRequest(allocator, "POST", "/users");
    defer allocator.free(res);
    // assertions...
}
```

## Testing with Database#

```zig
test "database query" {
    try spider.pg.init(allocator, io, .{});
    defer spider.pg.deinit();
    
    const users = try spider.pg.query(User, "SELECT * FROM users", .{});
    try std.testing.expect(users.len > 0);
}
```

## Test Coverage#

Use `zig build test` to run all tests:

```bash
zig build test

# Run specific test
zig test src/main.zig --test-filter "handler returns"
```

Spider's architecture (plain functions, arena-based memory) makes testing straightforward.
