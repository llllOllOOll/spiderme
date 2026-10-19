const spider = @import("spider");
const controller = @import("controller.zig");

/// Mounted by `server.mountFeatures(features)` in src/main.zig.
pub fn build() spider.Group {
    var g = spider.Group.init("");
    _ = g.get("/", controller.index, .{ .public = true });
    return g;
}
