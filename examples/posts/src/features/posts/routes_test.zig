const spider = @import("spider");
const routes = @import("routes.zig");

// The access contract of the posts routes: what `spider routes` prints
// for them. Changing a route, or who may call it, fails `zig build test`
// until this table changes too, so the change shows up in review. On a
// mismatch the test prints the actual table, ready to paste once intended.
test "posts routes: method, path and access" {
    try spider.testing.expectRoutes(routes.build(), &.{
        .{ "GET", "/posts", "public" },
        .{ "GET", "/posts/new", "authenticated" },
        .{ "GET", "/posts/export.csv", "public" },
        .{ "POST", "/posts/create", "authenticated" },
        .{ "GET", "/posts/:id", "public" },
        .{ "GET", "/posts/:id/edit", "authenticated" },
        .{ "POST", "/posts/:id/update", "authenticated" },
        .{ "GET", "/posts/:id/delete", "authenticated" },
        .{ "POST", "/posts/:id/delete", "authenticated" },
    });
}

test "api routes: method, path and access" {
    try spider.testing.expectRoutes(routes.api(), &.{
        .{ "GET", "/api/posts", "public" },
        .{ "GET", "/api/posts/:id", "public" },
        .{ "POST", "/api/posts", "public" },
    });
}

test "home route: method, path and access" {
    try spider.testing.expectRoutes(routes.home(), &.{
        .{ "GET", "/", "public" },
    });
}
