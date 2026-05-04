-- doc

# Graceful Shutdown#

Spider doesn't have built-in graceful shutdown yet (see TODOs). For now, use these approaches:

## Signal Handling (Linux)#

```zig
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    // Set up signal handlers
    var sa: std.posix.SigAction = .{ .handler = .{ .handler = sigHandler } };
    _ = std.posix.sigaction(std.posix.SIGINT, &sa, null);
    _ = std.posix.sigaction(std.posix.SIGTERM, &sa, null);
    
    var server = spider.app();
    defer server.deinit();
    
    server.get("/", handler).listen(8080) catch |err| {
        if (err == error.SigTerm) {
            std.debug.print("Shutting down gracefully...\n", .{});
            return;
        }
        return err;
    };
}

var should_stop = std.atomic.Atomic(bool).init(false);

fn sigHandler(sig: i32) void {
    should_stop.store(true, .Release);
}
```

## Docker Stop#

Docker sends `SIGTERM` to the process. Your app has 10 seconds (default) to clean up:

```bash
# Stop container gracefully
docker stop myapp

# Force after timeout
docker kill myapp
```

## Cleanup on Exit#

```zig
pub fn main(init: std.process.Init) !void {
    var server = spider.app();
    
    // Register cleanup
    defer {
        spider.pg.deinit();        // close DB pool
        // ... other cleanup
    }
    
    server.get("/", handler).listen(8080) catch {};
}
```

## Connection Draining#

Currently NOT implemented. PRs welcome!

## TODOs#

- [ ] Graceful shutdown (catch SIGTERM, stop accepting, drain connections)
- [ ] Connection draining (wait for active requests to finish)
- [ ] Request timeout (configurable per route or global)
