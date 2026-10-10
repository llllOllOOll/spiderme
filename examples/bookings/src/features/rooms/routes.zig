const spider = @import("spider");
const controller = @import("controller.zig");

const admins = &.{"admin"};

/// Routes of the rooms, mounted by `server.mountFeatures(features)` in
/// src/main.zig. Anyone may look at the rooms; only an admin changes them.
/// An account becomes an admin in the database:
///
///     UPDATE users SET role = 'admin' WHERE email = 'dana@example.org';
pub fn build() spider.Group {
    var g = spider.Group.init("/rooms");
    _ = g
        .defaults(.{ .public = true })
        .get("", controller.index, .{})
        .get("/new", controller.newForm, .{ .roles = admins })
        .post("/create", controller.create, .{ .roles = admins })
        .get("/:id", controller.show, .{})
        .get("/:id/edit", controller.edit, .{ .roles = admins })
        .post("/:id/update", controller.update, .{ .roles = admins })
        .post("/:id/delete", controller.delete, .{ .roles = admins });
    return g;
}
