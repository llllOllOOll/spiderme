-- doc

# Logger

Spider provides a colored console logger via `spider.env` and automatic request logging.

## Environment Control#

Set logging level with `SPIDER_LOG_LEVEL`:

```bash
# Options: debug, info, warn, error
SPIDER_LOG_LEVEL=debug
```

Auto-load order: `.env` → `.env.{SPIDER_ENV}` → `.env.local`

## Request Logging#

Spider automatically logs each request:

```
[[SPIDER]] | 200 | 125000ns | GET "/api/users"
[[SPIDER]] | 404 | 45000ns | GET "/missing"
[[SPIDER]] | 500 | 89000ns | POST "/error"
```

Format: `| status | duration | method "path"`

## Custom Logging#

```zig
const log = std.log;

// Info level
log.info("User {s} logged in", .{"Alice"});

// Warning
log.warn("Deprecated API called", .{});

// Error
log.err("Database connection failed: {s}", .{err_msg});
```

## With spider.env#

```zig
// Get log level from environment
const level = spider.env.getOr("SPIDER_LOG_LEVEL", "info");

// Check environment
if (spider.env.get("DEBUG")) |val| {
    log.debug("Debug mode active", .{});
}
```

## Log Levels#

| Level | Effect |
|-------|--------|
| `debug` | All messages |
| `info` | Info, warn, error (default) |
| `warn` | Warn and error only |
| `error` | Error only |

## Disabling Colors#

```bash
# For logs without ANSI colors
SPIDER_LOG_NO_COLOR=1
```

Useful for production logs piped to log aggregation services.
