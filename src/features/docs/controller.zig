const std = @import("std");
const spider = @import("spider");
const pages = @import("pages.zig");

const NavItem = struct { title: []const u8, href: []const u8, current: bool };
const NavSection = struct { title: []const u8, pages: []const NavItem };

/// The sidebar: the index grouped by section, in order. `current` is the
/// index of the page being shown (null on the search page).
fn nav(arena: std.mem.Allocator, current: ?usize) ![]const NavSection {
    var sections: std.ArrayList(NavSection) = .empty;
    inline for (comptime std.enums.values(pages.Section)) |section| {
        var items: std.ArrayList(NavItem) = .empty;
        for (pages.all, 0..) |entry, i| {
            if (entry.section != section) continue;
            try items.append(arena, .{
                .title = entry.title,
                .href = try std.fmt.allocPrint(arena, "/docs/{s}", .{entry.slug}),
                .current = current != null and current.? == i,
            });
        }
        if (items.items.len > 0) try sections.append(arena, .{ .title = pages.sectionTitle(section), .pages = items.items });
    }
    return sections.items;
}

/// GET / and GET /docs
pub fn index(c: *spider.Ctx) !spider.Response {
    return c.redirect("/docs/" ++ pages.first);
}

/// GET /docs/:page — the one route behind every documentation page.
pub fn page(c: *spider.Ctx) !spider.Response {
    const slug = c.params.get("page") orelse return error.NotFound;
    // Only the pages of content/docs exist: an unknown slug is a 404.
    const i = pages.indexOf(slug) orelse return error.NotFound;
    const current = pages.all[i];

    // The page's Markdown (compiled in, without its header) as HTML.
    const html = try spider.zmd.parse(c.arena, current.markdown, .{});

    const has_next = i + 1 < pages.all.len;
    return c.view("docs/page", .{
        .title = current.title,
        .content = spider.RawHtml{ .html = html },
        .sections = try nav(c.arena, i),
        .zig_version = pages.zig_version,
        .query = "",
        .is_page = true,
        .edit_url = try std.fmt.allocPrint(c.arena, "{s}{s}.md", .{ pages.edit_base, slug }),
        .has_next = has_next,
        .next_title = if (has_next) pages.all[i + 1].title else "",
        .next_href = if (has_next) try std.fmt.allocPrint(c.arena, "/docs/{s}", .{pages.all[i + 1].slug}) else "",
        .results = @as([]const NavItem, &.{}),
    }, .{});
}

/// GET /docs/search?q=… — pages whose title matches.
pub fn search(c: *spider.Ctx) !spider.Response {
    const query = c.queryDecoded("q") orelse "";
    var results: std.ArrayList(NavItem) = .empty;
    for (try pages.search(c.arena, query)) |found| {
        try results.append(c.arena, .{
            .title = found.title,
            .href = try std.fmt.allocPrint(c.arena, "/docs/{s}", .{found.slug}),
            .current = false,
        });
    }
    return c.view("docs/page", .{
        .title = "Search",
        .content = spider.RawHtml{ .html = "" },
        .sections = try nav(c.arena, null),
        .zig_version = pages.zig_version,
        .query = query,
        .is_page = false,
        .edit_url = "",
        .has_next = false,
        .next_title = "",
        .next_href = "",
        .results = results.items,
    }, .{});
}
