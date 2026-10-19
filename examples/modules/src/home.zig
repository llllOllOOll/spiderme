const spider = @import("spider");

pub const routes = struct {
    pub fn build() spider.Group {
        var g = spider.Group.init("/");
        _ = g.get("", index, .{ .public = true });
        return g;
    }
};

fn index(c: *spider.Ctx) !spider.Response {
    return c.text("An app with a module", .{});
}
