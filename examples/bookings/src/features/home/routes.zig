const spider = @import("spider");
const controller = @import("controller.zig");

/// Mounted by `server.mountFeatures(features)` in src/main.zig. `.public`:
/// the home page stays open once the app has a login (spider g auth).
pub fn build() spider.Group {
    var g = spider.Group.init("");
    _ = g
        .get("/", controller.index, .{ .public = true })
        // The stream that tells a day view its day changed.
        .sseWith("/events/:day", controller.events, .{ .public = true, .quiet_log = true });
    return g;
}
