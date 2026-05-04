-- doc

# Metrics#

Spider provides built-in metrics collection via `spider.metrics`. All metrics are atomic and thread-safe.

## Available Metrics#

| Metric | Type | Description |
|--------|------|-------------|
| `requests_total` | counter | Total requests processed |
| `requests_4xx` | counter | Client errors (400-499) |
| `requests_5xx` | counter | Server errors (500-599) |
| `response_time_ns` | histogram | Response time in nanoseconds |

## Access Metrics#

Metrics are exposed at `/spider/metrics` automatically when using `spider.app()` with default config.

```zig
var server = spider.app();
server.listen(8080) catch {};

// GET /spider/metrics returns:
// spider_requests_total 42
// spider_requests_4xx 3
// spider_requests_5xx 1
// spider_response_time_ns{quantile="0.5"} 125000
// spider_response_time_ns{quantile="0.9"} 450000
// spider_response_time_ns{quantile="0.99"} 1200000
```

## Custom Metrics#

```zig
const metrics = spider.metrics;

pub fn handler(c: *spider.Ctx) !spider.Response {
    metrics.inc("api_calls");
    const start = std.time.nanoTimestamp();
    defer {
        const duration = std.time.nanoTimestamp() - start;
        metrics.observe("handler_duration_ns", duration);
    }
    return c.json(.{ .ok = true }, .{});
}
```

## Reset Metrics#

```zig
// Reset all metrics (useful for testing)
spider.metrics.reset();
```

## Dashboard#

Spider includes a built-in metrics dashboard at `/spider/dashboard` when using `spider.app()`:

```zig
var server = spider.app();
server.listen(8080) catch {};

// Visit http://localhost:8080/spider/dashboard
```

The dashboard shows real-time request rates, error percentages, and response time percentiles.
