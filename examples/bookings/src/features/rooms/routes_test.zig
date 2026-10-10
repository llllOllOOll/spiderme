const spider = @import("spider");
const routes = @import("routes.zig");

// The access contract of the rooms routes: what `spider routes` prints for
// them. Changing a route, or who may call it, fails `zig build test` until
// this table changes too.
test "rooms routes: method, path and access" {
    try spider.testing.expectRoutes(routes.build(), &.{
        .{ "GET", "/rooms", "public" },
        .{ "GET", "/rooms/:id", "public" },
    });
}
