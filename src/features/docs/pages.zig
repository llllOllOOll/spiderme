//! The documentation pages, as the site sees them.
//!
//! The pages are the Markdown files in content/docs. Each one starts with a
//! header (title, section, order); tools/docs_index.zig reads them at build
//! time and generates the `docs_index` module used here. **To add a page,
//! write one `.md` file there. Nothing in this directory changes.**

const std = @import("std");
const index = @import("docs_index");

pub const Page = index.Page;
pub const Section = index.Section;

/// Every page, in reading order (by section, then by `order`).
pub const all = index.all;

/// The name of a group in the sidebar.
pub fn sectionTitle(section: Section) []const u8 {
    return switch (section) {
        .start => "Start",
        .guide => "Guide",
        .reference => "Reference",
    };
}

/// Where `/` and `/docs` go.
pub const first = all[0].slug;

/// The Zig release the documentation is written for (shown in the header).
pub const zig_version = "0.17.0";

/// "Edit this page" links to `edit_base ++ slug ++ ".md"`.
pub const edit_base = "https://github.com/llllOllOOll/spiderme/edit/main/content/docs/";

pub fn indexOf(slug: []const u8) ?usize {
    for (all, 0..) |page, i| {
        if (std.mem.eql(u8, page.slug, slug)) return i;
    }
    return null;
}

/// Pages whose title or slug contains `query`, ignoring case, in reading
/// order. An empty query matches nothing.
pub fn search(arena: std.mem.Allocator, query: []const u8) ![]const Page {
    const needle = std.mem.trim(u8, query, " \t");
    var found: std.ArrayList(Page) = .empty;
    if (needle.len == 0) return found.items;
    for (all) |page| {
        if (std.ascii.findIgnoreCase(page.title, needle) != null or
            std.ascii.findIgnoreCase(page.slug, needle) != null)
        {
            try found.append(arena, page);
        }
    }
    return found.items;
}

test "slugs are unique and safe to put in a path" {
    for (all, 0..) |page, i| {
        try std.testing.expect(page.slug.len > 0);
        for (page.slug) |ch| try std.testing.expect(std.ascii.isAlphanumeric(ch) or ch == '-' or ch == '_');
        try std.testing.expectEqual(i, indexOf(page.slug).?);
    }
    try std.testing.expectEqual(@as(?usize, null), indexOf("../main"));
    try std.testing.expectEqual(@as(?usize, null), indexOf(""));
}

test "every page has a title and text, and the pages are in reading order" {
    try std.testing.expect(all.len > 0);
    for (all, 0..) |page, i| {
        try std.testing.expect(page.title.len > 0);
        try std.testing.expect(std.mem.trim(u8, page.markdown, " \r\n\t").len > 0);
        // No leftover header in the text that gets rendered.
        try std.testing.expect(!std.mem.startsWith(u8, page.markdown, "---"));
        if (i == 0) continue;
        const previous = all[i - 1];
        const a = @backingInt(previous.section);
        const b = @backingInt(page.section);
        try std.testing.expect(a < b or (a == b and previous.order < page.order));
    }
}

test "search: by title or slug, any case; nothing for an empty query" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const routing = try search(arena, "ROUT");
    try std.testing.expectEqual(@as(usize, 1), routing.len);
    try std.testing.expectEqualStrings("router", routing[0].slug);
    try std.testing.expectEqual(@as(usize, 0), (try search(arena, "  ")).len);
    try std.testing.expectEqual(@as(usize, 0), (try search(arena, "no such page")).len);
}
