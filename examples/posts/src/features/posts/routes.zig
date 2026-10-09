const spider = @import("spider");
const controller = @import("controller.zig");
const api_handlers = @import("api.zig");

/// Routes of the posts feature. src/main.zig mounts them with
/// `server.mountFeatures(features)`: every pub fn here with no parameters
/// that returns a spider.Group. Paths are relative to the group prefix.
///
/// Reading is for everyone: `defaults` makes the routes public. Writing
/// needs a login: those routes say `.authenticated`, which replaces the
/// default for them.
pub fn build() spider.Group {
    const signed_in = .{ .authenticated = true };
    var g = spider.Group.init("/posts");
    _ = g
        .defaults(.{ .public = true })
        .get("", controller.index, .{})
        .get("/export.csv", controller.exportCsv, .{})
        .get("/new", controller.new, signed_in)
        .post("/create", controller.create, signed_in)
        .get("/:id", controller.show, .{})
        .get("/:id/edit", controller.edit, signed_in)
        .post("/:id/update", controller.update, signed_in)
        .get("/:id/delete", controller.confirmDelete, signed_in)
        .post("/:id/delete", controller.delete, signed_in);
    return g;
}

/// The same posts as JSON, for programs. Two middlewares wrap every route
/// of this group, and only of this group: the first asks for the API key,
/// the second marks the answers as not to be cached.
pub fn api() spider.Group {
    var g = spider.Group.init("/api/posts");
    _ = g
        .defaults(.{ .public = true })
        .use(api_handlers.requireKey)
        .use(api_handlers.noStore)
        .get("", api_handlers.list, .{})
        .get("/:id", api_handlers.show, .{})
        .post("", api_handlers.create, .{});
    return g;
}

/// The address of the site itself goes to the feed.
pub fn home() spider.Group {
    var g = spider.Group.init("");
    _ = g.get("/", controller.home, .{ .public = true });
    return g;
}
