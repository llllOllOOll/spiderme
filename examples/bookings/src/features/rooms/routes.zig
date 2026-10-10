const spider = @import("spider");
const controller = @import("controller.zig");

/// Routes of the rooms, mounted by `server.mountFeatures(features)` in
/// src/main.zig. Anyone may look at the rooms.
pub fn build() spider.Group {
    var g = spider.Group.init("/rooms");
    _ = g
        .defaults(.{ .public = true })
        .get("", controller.index, .{})
        .get("/:id", controller.show, .{});
    return g;
}
