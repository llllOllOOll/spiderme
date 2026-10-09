const spider = @import("spider");
const routes = @import("routes.zig");

// The access contract of the docs routes (see spider routes / routes.zig).
test "docs routes: method, path and access" {
    try spider.testing.expectRoutes(routes.build(), &.{
        .{ "GET", "/", "public" },
        .{ "GET", "/docs", "public" },
        .{ "GET", "/docs/search", "public" },
        .{ "GET", "/docs/:page", "public" },
    });
}
