const spider = @import("spider");
const controller = @import("controller.zig");

/// Routes of the bookings, mounted by `server.mountFeatures(features)` in
/// src/main.zig. Anyone reads a booking; making one, and the list of one's
/// own, need an account. Who may confirm or cancel is checked in the
/// handler: the owner, or an admin.
pub fn build() spider.Group {
    var g = spider.Group.init("/bookings");
    _ = g
        .defaults(.{ .authenticated = true })
        .get("", controller.mine, .{})
        .get("/new", controller.newForm, .{})
        .post("/create", controller.create, .{})
        .get("/:id", controller.show, .{ .public = true })
        .post("/:id/confirm", controller.confirm, .{})
        .post("/:id/cancel", controller.cancel, .{});
    return g;
}
