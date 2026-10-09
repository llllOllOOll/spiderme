const spider = @import("spider");
const controller = @import("controller.zig");

/// Mounted by `server.mountFeatures(features)` in src/main.zig. One route
/// serves every page: which pages exist is decided by pages.zig.
pub fn build() spider.Group {
    var g = spider.Group.init("");
    _ = g.get("/", controller.index, .{ .public = true });
    _ = g.get("/docs", controller.index, .{ .public = true });
    _ = g.get("/docs/search", controller.search, .{ .public = true });
    _ = g.get("/docs/:page", controller.page, .{ .public = true });
    return g;
}
