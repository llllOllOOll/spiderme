const spider = @import("spider");

/// Routes of the bookings feature, mounted by `server.mountFeatures(features)` in
/// src/main.zig. None yet: the pages come next.
pub fn build() spider.Group {
    return spider.Group.init("/bookings");
}
