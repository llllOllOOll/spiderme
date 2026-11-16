const std = @import("std");
const spider = @import("spider");
const pages = @import("pages.zig");

const NavItem = struct { title: []const u8, href: []const u8, current: bool };
const TocItem = struct { title: []const u8, id: []const u8 };

/// The colours a reader picked with the switch in the header, kept in the
/// `theme` cookie. Without the cookie the page follows the system.
pub const Theme = enum { light, dark, system };

/// The `data-theme` of `<html>`: "light", "dark", or "" to follow the system.
fn themeOf(c: *spider.Ctx) []const u8 {
    const value = c.cookie("theme") orelse return "";
    const picked = std.meta.stringToEnum(Theme, value) orelse return "";
    return switch (picked) {
        .light => "light",
        .dark => "dark",
        .system => "",
    };
}

/// The page to go back to after switching colours: a page of this site,
/// never an address elsewhere (`//host` included). "/" for anything else.
pub fn safeBack(back: ?[]const u8) []const u8 {
    const path = back orelse return "/";
    if (path.len == 0 or path[0] != '/') return "/";
    if (path.len > 1 and (path[1] == '/' or path[1] == '\\')) return "/";
    for (path) |ch| if (ch < 0x20 or ch == 0x7f) return "/";
    return path;
}

test "safeBack: only a path of this site" {
    try std.testing.expectEqualStrings("/docs/router", safeBack("/docs/router"));
    try std.testing.expectEqualStrings("/docs/router#Methods", safeBack("/docs/router#Methods"));
    try std.testing.expectEqualStrings("/", safeBack(null));
    try std.testing.expectEqualStrings("/", safeBack(""));
    try std.testing.expectEqualStrings("/", safeBack("https://example.com/"));
    try std.testing.expectEqualStrings("/", safeBack("//example.com"));
    try std.testing.expectEqualStrings("/", safeBack("/\\example.com"));
    try std.testing.expectEqualStrings("/", safeBack("/docs\r\nSet-Cookie: x=1"));
}

/// The `## ` headings of a page's Markdown, for "On this page", with the
/// same ids the rendered headings get. Lines inside code blocks are not
/// headings.
pub fn toc(arena: std.mem.Allocator, markdown: []const u8) ![]const TocItem {
    var items: std.ArrayList(TocItem) = .empty;
    var in_code = false;
    var lines = std.mem.splitScalar(u8, markdown, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        if (std.mem.startsWith(u8, line, "```")) {
            in_code = !in_code;
            continue;
        }
        if (in_code or !std.mem.startsWith(u8, line, "## ")) continue;
        const text = std.mem.trim(u8, line[3..], " ");
        // The title as it reads: the backticks of code names left out.
        const title = try std.mem.replaceOwned(u8, arena, text, "`", "");
        try items.append(arena, .{ .title = title, .id = try headingId(arena, text) });
    }
    return items.items;
}

test "toc: the h2 headings, with the ids of the page, code blocks skipped" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const items = try toc(arena.allocator(), "# Title\n\n## Moving from 0.12 to 0.14\n\n```bash\n## not a heading\n```\n\n### Deeper\n\n## The `secret`\n");
    try std.testing.expectEqual(@as(usize, 2), items.len);
    try std.testing.expectEqualStrings("Moving from 0.12 to 0.14", items[0].title);
    try std.testing.expectEqualStrings("Moving-from-0-12-to-0-14", items[0].id);
    try std.testing.expectEqualStrings("The secret", items[1].title);
    try std.testing.expectEqualStrings("The-secret", items[1].id);
}
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
        .theme = themeOf(c),
        .path = try std.fmt.allocPrint(c.arena, "/docs/{s}", .{slug}),
        .overview = std.mem.eql(u8, slug, "overview"),
        .toc = try toc(c.arena, current.markdown),
        .spider_version = pages.spider_version,
        .stable_version = pages.stable_version,
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
        .theme = themeOf(c),
        .path = "/docs/search",
        .overview = false,
        .toc = @as([]const TocItem, &.{}),
        .spider_version = pages.spider_version,
        .stable_version = pages.stable_version,
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

/// GET /theme/:mode?back=/docs/… — keeps the reader's choice of colours in
/// a cookie for a year and goes back to the page. No JavaScript: the switch
/// in the header is three links.
pub fn theme(c: *spider.Ctx, mode: spider.Path(Theme, "mode")) !spider.Response {
    return c.redirectWith(safeBack(c.queryDecoded("back")), try c.withCookie("theme", @tagName(mode.value), .{
        .path = "/",
        .max_age = 365 * 24 * 60 * 60,
        .same_site = "Lax",
        .http_only = true,
    }));
}
