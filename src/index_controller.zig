const std = @import("std");
const spider = @import("spider");

pub const IndexController = @This();

pub fn index(alc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    const is_boosted = req.headers.get("HX-Boosted") != null;
    const is_htmx = req.headers.get("HX-Request") != null;

    if (is_htmx and !is_boosted) {
        const html = try spider.template.renderBlock(@embedFile("views/index_content.html"), "content", .{}, alc);
        return spider.Response.html(alc, html);
    }

    const layout = @embedFile("views/layout_index.html");
    const view = @embedFile("views/index_content.html");
    const tmpl = try std.mem.concat(alc, u8, &.{ layout, view });
    defer alc.free(tmpl);
    const html = try spider.template.renderBlock(tmpl, "layout_index", .{}, alc);
    return spider.Response.html(alc, html);
}
