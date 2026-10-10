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

/// Headings with an `id` made from their text: `<h3 id="ctx-json">`.
/// tools/api_reference.zig makes the same id for the links it writes.
const headings = struct {
    fn h2(allocator: std.mem.Allocator, node: spider.zmd.Node) std.mem.Allocator.Error![]const u8 {
        return heading(allocator, "h2", node.content);
    }
    fn h3(allocator: std.mem.Allocator, node: spider.zmd.Node) std.mem.Allocator.Error![]const u8 {
        return heading(allocator, "h3", node.content);
    }
    fn h4(allocator: std.mem.Allocator, node: spider.zmd.Node) std.mem.Allocator.Error![]const u8 {
        return heading(allocator, "h4", node.content);
    }

    fn heading(allocator: std.mem.Allocator, comptime tag: []const u8, content: []const u8) ![]const u8 {
        const id = try headingId(allocator, content);
        defer allocator.free(id);
        return std.fmt.allocPrint(allocator, "<" ++ tag ++ " id=\"{s}\">{s}</" ++ tag ++ ">\n", .{ id, content });
    }
};

/// Anything but letters and digits a single `-`, the case kept; what is
/// inside `<...>` (markup the heading already has) does not count.
pub fn headingId(allocator: std.mem.Allocator, content: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var in_tag = false;
    for (content) |ch| {
        if (ch == '<') in_tag = true;
        if (in_tag) {
            if (ch == '>') in_tag = false;
            continue;
        }
        if (std.ascii.isAlphanumeric(ch)) {
            try out.append(allocator, ch);
        } else if (out.items.len > 0 and out.items[out.items.len - 1] != '-') {
            try out.append(allocator, '-');
        }
    }
    while (out.items.len > 0 and out.items[out.items.len - 1] == '-') _ = out.pop();
    return out.toOwnedSlice(allocator);
}

test "headingId: the same ids the API reference links to" {
    const a = std.testing.allocator;
    inline for (.{
        .{ "spider.Ctx", "spider-Ctx" },
        .{ "Ctx.redirectWith", "Ctx-redirectWith" },
        .{ "pg.Transaction.commit", "pg-Transaction-commit" },
        .{ "auth (HS256 tokens)", "auth-HS256-tokens" },
        .{ "The <code>secret</code>", "The-secret" },
    }) |case| {
        const id = try headingId(a, case[0]);
        defer a.free(id);
        try std.testing.expectEqualStrings(case[1], id);
    }
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
    // Headings get an id, so a page can be linked to at one of them.
    const html = try spider.zmd.parse(c.arena, current.markdown, .{ .h2 = headings.h2, .h3 = headings.h3, .h4 = headings.h4 });

    const has_next = i + 1 < pages.all.len;
    return c.view("docs/page", .{
        .title = current.title,
        .content = spider.RawHtml{ .html = html },
        .sections = try nav(c.arena, i),
        .zig_version = pages.zig_version,
        .query = "",
        .is_page = true,
        // A page written by hand is edited as a file of this site; a
        // generated one in the comments of the file of Spider it shows.
        .edit_url = if (current.source.len == 0)
            try std.fmt.allocPrint(c.arena, "{s}{s}.md", .{ pages.edit_base, slug })
        else
            try std.fmt.allocPrint(c.arena, "{s}{s}", .{ pages.source_base, current.source }),
        .edit_label = if (current.source.len == 0) "Edit this page" else "Generated from the comments in this file",
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
        .edit_label = "",
        .has_next = false,
        .next_title = "",
        .next_href = "",
        .results = results.items,
    }, .{});
}
