const spider = @import("spider");

pub const config = spider.Config{
    // No template in this package.
    .views_dir = null,
    // The proxy in front of the app: its X-Forwarded-For is believed, and
    // nobody else's. The tests talk to the server from this address.
    .trusted_proxies = &.{"127.0.0.1"},
    // A payment provider posts to /hooks/... from its own site, in the
    // visitor's browser: the one place a cross-site POST is expected.
    .origin_check = .{ .exempt_paths = &.{"/hooks/"} },
    // Nothing larger than this is read: an upload over it gets a 413.
    .max_body_bytes = 1024 * 1024,
};
