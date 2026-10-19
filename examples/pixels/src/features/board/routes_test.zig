const spider = @import("spider");
const routes = @import("routes.zig");

// The access contract of the board routes (see spider routes / routes.zig).
test "board routes: method, path and access" {
    try spider.testing.expectRoutes(routes.build(), &.{
        .{ "GET", "/", "public" },
    });
}
