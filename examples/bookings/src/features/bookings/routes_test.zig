const spider = @import("spider");
const routes = @import("routes.zig");

// The access contract of the bookings routes: what `spider routes` prints
// for them. Changing a route, or who may call it, fails `zig build test`
// until this table changes too.
test "bookings routes: method, path and access" {
    try spider.testing.expectRoutes(routes.build(), &.{
        .{ "GET", "/bookings", "authenticated" },
        .{ "GET", "/bookings/new", "authenticated" },
        .{ "POST", "/bookings/create", "authenticated" },
        .{ "GET", "/bookings/:id", "public" },
        .{ "POST", "/bookings/:id/confirm", "policy:booking.confirm" },
        .{ "POST", "/bookings/:id/cancel", "policy:booking.cancel" },
    });
}
