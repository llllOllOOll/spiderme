const spider = @import("spider");

/// Routes of the rooms feature, mounted by `server.mountFeatures(features)` in
/// src/main.zig. None yet: the pages come next.
pub fn build() spider.Group {
    return spider.Group.init("/rooms");
}
