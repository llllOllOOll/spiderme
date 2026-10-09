const spider = @import("spider");
const controller = @import("controller.zig");
const api_handlers = @import("api.zig");

/// Routes of the posts feature. src/main.zig mounts them with
/// `server.mountFeatures(features)`: every pub fn here with no parameters
/// that returns a spider.Group. Paths are relative to the group prefix.
///
/// The app has no login, so every route is public. A route's own config
/// (the third argument) would replace these defaults.
pub fn build() spider.Group {
    var g = spider.Group.init("/posts");
    _ = g
        .defaults(.{ .public = true })
        .get("", controller.index, .{})
        .get("/new", controller.new, .{})
        .get("/export.csv", controller.exportCsv, .{})
        .post("/create", controller.create, .{})
        .get("/:id", controller.show, .{})
        .get("/:id/edit", controller.edit, .{})
        .post("/:id/update", controller.update, .{})
        .get("/:id/delete", controller.confirmDelete, .{})
        .post("/:id/delete", controller.delete, .{});
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
