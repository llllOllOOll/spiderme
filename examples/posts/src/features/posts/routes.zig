const spider = @import("spider");
const controller = @import("controller.zig");

/// Routes of the posts feature. src/main.zig mounts them with
/// `server.mountFeatures(features)`: every pub fn here with no parameters
/// that returns a spider.Group. Paths are relative to the group prefix.
///
/// The 3rd argument of each route is its config, checked at compile time:
/// .roles / .org_roles (who may call it), .authenticated (any logged-in
/// user), .public (no login needed), .policy = spider.policy("name", fn)
/// (a rule that isn't a role, e.g. owns the record), .quiet_log (don't log
/// successful requests), .allow_http (skip forceHttps).
/// A route that sets .roles, .org_roles, .authenticated, .policy or .public
/// replaces the defaults().
pub fn build() spider.Group {
    var g = spider.Group.init("/posts");
    _ = g
        // Who may use these routes. Once the app has auth (spider g auth),
        // enable this and set the role; until then every route is open:
        // .defaults(.{ .roles = &.{"posts_admin"} })
        .get("", controller.index, .{})
        .get("/new", controller.newForm, .{})
        .get("/:id/edit", controller.edit, .{})
        .post("/create", controller.create, .{})
        .post("/:id/update", controller.update, .{})
        .post("/:id/delete", controller.delete, .{});
    return g;
}
