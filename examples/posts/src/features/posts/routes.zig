const spider = @import("spider");
const controller = @import("controller.zig");

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
        .post("/create", controller.create, .{})
        .get("/:id", controller.show, .{})
        .get("/:id/edit", controller.edit, .{})
        .post("/:id/update", controller.update, .{})
        .get("/:id/delete", controller.confirmDelete, .{})
        .post("/:id/delete", controller.delete, .{});
    return g;
}

/// The address of the site itself goes to the feed.
pub fn home() spider.Group {
    var g = spider.Group.init("");
    _ = g.get("/", controller.home, .{ .public = true });
    return g;
}
