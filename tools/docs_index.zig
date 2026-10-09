//! Build-time tool: turns the Markdown pages in content/docs into the index
//! the site compiles in.
//!
//! Usage: docs-index <content dir> <out.zig>
//!
//! A page is a Markdown file whose name is its address (`router.md` is
//! `/docs/router`) and that starts with a header:
//!
//!     ---
//!     title: Routing
//!     section: guide
//!     order: 10
//!     ---
//!
//! `title` is the name in the sidebar and in "Next: ..."; `section` is one of
//! `Section` below; `order` places the page inside its section (lowest
//! first). All three are required. A page with a missing or incomplete
//! header, an unknown section, or the order of another page of its section
//! stops the build, naming the file. So does a link to `/docs/<slug>` when no
//! page has that slug.
//!
//! The content stays plain Markdown with a standard header: nothing in a
//! page is specific to this site.

const std = @import("std");

/// The groups of the sidebar, in the order they are shown.
pub const Section = enum { start, guide, reference };

pub const Meta = struct {
    title: []const u8,
    section: Section,
    order: u32,
    /// The Markdown after the header.
    body: []const u8,
};

pub const HeaderError = error{
    /// The file does not start with a `---` line.
    MissingHeader,
    /// No closing `---` line.
    UnclosedHeader,
    MissingTitle,
    MissingSection,
    MissingOrder,
    /// `section:` is not one of `Section`.
    UnknownSection,
    /// `order:` is not a whole number.
    InvalidOrder,
    /// A line of the header is not `key: value`, or the key is not known.
    InvalidHeaderLine,
};

/// Reads the header of one page.
pub fn parse(source: []const u8) HeaderError!Meta {
    var rest = source;
    // A byte order mark some editors add.
    if (std.mem.startsWith(u8, rest, "\xEF\xBB\xBF")) rest = rest[3..];

    var lines = std.mem.splitScalar(u8, rest, '\n');
    const first = std.mem.trimEnd(u8, lines.next() orelse return error.MissingHeader, " \r\t");
    if (!std.mem.eql(u8, first, "---")) return error.MissingHeader;

    var title: ?[]const u8 = null;
    var section: ?Section = null;
    var order: ?u32 = null;
    while (true) {
        const raw = lines.next() orelse return error.UnclosedHeader;
        const line = std.mem.trim(u8, raw, " \r\t");
        if (std.mem.eql(u8, line, "---")) break;
        if (line.len == 0) continue;
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse return error.InvalidHeaderLine;
        const key = std.mem.trim(u8, line[0..colon], " \t");
        var value = std.mem.trim(u8, line[colon + 1 ..], " \t");
        if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') value = value[1 .. value.len - 1];

        if (std.mem.eql(u8, key, "title")) {
            if (value.len > 0) title = value;
        } else if (std.mem.eql(u8, key, "section")) {
            section = std.meta.stringToEnum(Section, value) orelse return error.UnknownSection;
        } else if (std.mem.eql(u8, key, "order")) {
            order = std.fmt.parseInt(u32, value, 10) catch return error.InvalidOrder;
        } else return error.InvalidHeaderLine;
    }

    return .{
        .title = title orelse return error.MissingTitle,
        .section = section orelse return error.MissingSection,
        .order = order orelse return error.MissingOrder,
        .body = std.mem.trimStart(u8, lines.rest(), "\r\n"),
    };
}

pub const Page = struct {
    slug: []const u8,
    meta: Meta,
};

pub const IndexError = error{
    /// Two pages with the same address.
    DuplicateSlug,
    /// Two pages of one section with the same `order`.
    DuplicateOrder,
    /// A file name that is not letters, digits, `-` and `_`.
    InvalidSlug,
};

pub fn validSlug(slug: []const u8) bool {
    if (slug.len == 0) return false;
    for (slug) |ch| {
        if (!std.ascii.isLower(ch) and !std.ascii.isDigit(ch) and ch != '-' and ch != '_') return false;
    }
    return true;
}

/// Checks the pages as a set. `problem` receives the slug at fault.
pub fn check(pages: []const Page, problem: *[]const u8) IndexError!void {
    for (pages, 0..) |page, i| {
        problem.* = page.slug;
        if (!validSlug(page.slug)) return error.InvalidSlug;
        for (pages[0..i]) |earlier| {
            if (std.mem.eql(u8, earlier.slug, page.slug)) return error.DuplicateSlug;
            if (earlier.meta.section == page.meta.section and earlier.meta.order == page.meta.order) return error.DuplicateOrder;
        }
    }
}

pub const LinkError = error{
    /// A link to `/docs/<slug>` and no page with that slug.
    BrokenLink,
};

/// The slug an internal link points at: what follows `/docs/` up to the end
/// of the path. Null for a link that is not `/docs/<slug>` (`/docs` itself,
/// another site, another path).
fn linkedSlug(target: []const u8) ?[]const u8 {
    const prefix = "/docs/";
    if (!std.mem.startsWith(u8, target, prefix)) return null;
    const rest = target[prefix.len..];
    const end = std.mem.indexOfAny(u8, rest, "#?/ \t\"") orelse rest.len;
    return if (end == 0) null else rest[0..end];
}

/// Checks every Markdown link `](/docs/<slug>...)` of every page. `problem`
/// receives "<page> links to /docs/<slug>" for the first one that points
/// nowhere; the text lives in `arena`.
pub fn checkLinks(arena: std.mem.Allocator, pages: []const Page, problem: *[]const u8) (LinkError || std.mem.Allocator.Error)!void {
    for (pages) |page| {
        var rest = page.meta.body;
        while (std.mem.indexOf(u8, rest, "](")) |at| {
            rest = rest[at + 2 ..];
            const close = std.mem.indexOfScalar(u8, rest, ')') orelse break;
            const slug = linkedSlug(rest[0..close]) orelse continue;
            for (pages) |other| {
                if (std.mem.eql(u8, other.slug, slug)) break;
            } else {
                problem.* = try std.fmt.allocPrint(arena, "{s} links to /docs/{s}", .{ page.slug, slug });
                return error.BrokenLink;
            }
        }
    }
}

/// Reading order: by section, then `order`.
fn readingOrder(_: void, a: Page, b: Page) bool {
    if (a.meta.section != b.meta.section) return @backingInt(a.meta.section) < @backingInt(b.meta.section);
    return a.meta.order < b.meta.order;
}

/// Every `.md` file of `dir_path`, parsed, checked and in reading order.
/// `problem` receives the file (or slug) at fault when it fails.
pub fn load(io: std.Io, arena: std.mem.Allocator, dir_path: []const u8, problem: *[]const u8) ![]Page {
    var dir = try std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
    defer dir.close(io);

    var pages: std.ArrayList(Page) = .empty;
    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".md")) continue;
        const name = try arena.dupe(u8, entry.name);
        problem.* = name;
        const source = try dir.readFileAlloc(io, name, arena, .limited(4 * 1024 * 1024));
        try pages.append(arena, .{ .slug = name[0 .. name.len - ".md".len], .meta = try parse(source) });
    }
    try check(pages.items, problem);
    try checkLinks(arena, pages.items, problem);
    std.mem.sort(Page, pages.items, {}, readingOrder);
    return pages.items;
}

fn write(w: *std.Io.Writer, pages: []const Page) !void {
    try w.writeAll(
        \\//! Generated by tools/docs_index.zig from content/docs/*.md. Do not edit:
        \\//! change the pages (or their headers) and build again.
        \\
        \\pub const Section = enum { start, guide, reference };
        \\
        \\pub const Page = struct {
        \\    /// The address (`/docs/<slug>`): the file name without `.md`.
        \\    slug: []const u8,
        \\    title: []const u8,
        \\    section: Section,
        \\    order: u32,
        \\    /// The page's Markdown, without its header.
        \\    markdown: []const u8,
        \\};
        \\
        \\/// Every page, in reading order.
        \\pub const all = [_]Page{
        \\
    );
    for (pages) |page| {
        try w.print(
            "    .{{ .slug = \"{f}\", .title = \"{f}\", .section = .{s}, .order = {d}, .markdown = \"{f}\" }},\n",
            .{
                std.zig.fmtString(page.slug),
                std.zig.fmtString(page.meta.title),
                @tagName(page.meta.section),
                page.meta.order,
                std.zig.fmtString(page.meta.body),
            },
        );
    }
    try w.writeAll("};\n");
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, arena);
    defer args.deinit();
    _ = args.next();
    const dir_path = args.next() orelse usage();
    const out_path = args.next() orelse usage();

    var problem: []const u8 = dir_path;
    const pages = load(io, arena, dir_path, &problem) catch |err| {
        std.debug.print("docs: {s}: {s}\n", .{ problem, @errorName(err) });
        if (err != error.BrokenLink) std.debug.print("  every page needs a header: ---, title:, section: (start|guide|reference), order:, ---\n", .{});
        std.process.exit(1);
    };
    if (pages.len == 0) {
        std.debug.print("docs: no .md page in {s}\n", .{dir_path});
        std.process.exit(1);
    }

    const file = try std.Io.Dir.cwd().createFile(io, out_path, .{});
    defer file.close(io);
    var buf: [8192]u8 = undefined;
    var writer: std.Io.File.Writer = .init(file, io, &buf);
    try write(&writer.interface, pages);
    try writer.interface.flush();
}

fn usage() noreturn {
    std.debug.print("usage: docs-index <content dir> <out.zig>\n", .{});
    std.process.exit(2);
}

// ── tests ───────────────────────────────────────────────────────────────

const t = std.testing;

test "parse: a complete header and the Markdown after it" {
    const meta = try parse("---\ntitle: Routing\nsection: guide\norder: 10\n---\n\n# Routing\n\nText.\n");
    try t.expectEqualStrings("Routing", meta.title);
    try t.expectEqual(Section.guide, meta.section);
    try t.expectEqual(@as(u32, 10), meta.order);
    try t.expectEqualStrings("# Routing\n\nText.\n", meta.body);
}

test "parse: quotes, blank lines, Windows line endings and a byte order mark" {
    const meta = try parse("\xEF\xBB\xBF---\r\ntitle: \"API: from source\"\r\n\r\nsection: reference\r\norder: 1\r\n---\r\nBody");
    try t.expectEqualStrings("API: from source", meta.title);
    try t.expectEqual(Section.reference, meta.section);
    try t.expectEqualStrings("Body", meta.body);
}

test "parse: a missing or incomplete header is an error that says what is wrong" {
    try t.expectError(error.MissingHeader, parse("# Routing\n\nNo header.\n"));
    try t.expectError(error.MissingHeader, parse(""));
    try t.expectError(error.UnclosedHeader, parse("---\ntitle: Routing\nsection: guide\norder: 1\n"));
    try t.expectError(error.MissingTitle, parse("---\nsection: guide\norder: 1\n---\n"));
    try t.expectError(error.MissingTitle, parse("---\ntitle:\nsection: guide\norder: 1\n---\n"));
    try t.expectError(error.MissingSection, parse("---\ntitle: Routing\norder: 1\n---\n"));
    try t.expectError(error.MissingOrder, parse("---\ntitle: Routing\nsection: guide\n---\n"));
    try t.expectError(error.UnknownSection, parse("---\ntitle: Routing\nsection: guides\norder: 1\n---\n"));
    try t.expectError(error.InvalidOrder, parse("---\ntitle: Routing\nsection: guide\norder: first\n---\n"));
    try t.expectError(error.InvalidHeaderLine, parse("---\ntitle: Routing\nsection: guide\norder: 1\nauthor: me\n---\n"));
    try t.expectError(error.InvalidHeaderLine, parse("---\njust text\n---\n"));
}

fn fake(slug: []const u8, section: Section, order: u32) Page {
    return .{ .slug = slug, .meta = .{ .title = "T", .section = section, .order = order, .body = "" } };
}

test "check: a repeated slug, a repeated order in one section, a bad file name" {
    var problem: []const u8 = "";
    try check(&.{ fake("a", .start, 1), fake("b", .start, 2), fake("c", .guide, 1) }, &problem);

    try t.expectError(error.DuplicateSlug, check(&.{ fake("router", .guide, 1), fake("router", .guide, 2) }, &problem));
    try t.expectEqualStrings("router", problem);
    try t.expectError(error.DuplicateOrder, check(&.{ fake("a", .guide, 5), fake("b", .guide, 5) }, &problem));
    try t.expectEqualStrings("b", problem);
    try t.expectError(error.InvalidSlug, check(&.{fake("My Page", .guide, 1)}, &problem));
    try t.expectError(error.InvalidSlug, check(&.{fake("../main", .guide, 1)}, &problem));
}

fn withBody(slug: []const u8, body: []const u8) Page {
    return .{ .slug = slug, .meta = .{ .title = "T", .section = .guide, .order = 1, .body = body } };
}

test "checkLinks: a link to a page that does not exist fails and names both ends" {
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var problem: []const u8 = "";

    try t.expectError(error.BrokenLink, checkLinks(arena, &.{
        withBody("router", "Next: [Requests](/docs/requests)."),
        withBody("request", "Back to [Routing](/docs/router)."),
    }, &problem));
    try t.expectEqualStrings("router links to /docs/requests", problem);

    // The anchor and the query are not part of the slug.
    try t.expectError(error.BrokenLink, checkLinks(arena, &.{withBody("a", "[x](/docs/b#top)")}, &problem));
    try t.expectEqualStrings("a links to /docs/b", problem);
}

test "checkLinks: links that resolve, and links that are not to a page, pass" {
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    var problem: []const u8 = "";
    try checkLinks(arena_state.allocator(), &.{
        withBody("router", "[Request](/docs/request), [again](/docs/request#body), [q](/docs/request?x=1), " ++
            "[home](/docs), [site](https://example.com/docs/nope), [mail](mailto:a@b.c), [self](#top), [file](/favicon.png)."),
        withBody("request", "No links. An index like a[0](b) is not a docs link."),
    }, &problem);
}

test "the pages of this site: complete headers, no repeated address or order, no broken link" {
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    var problem: []const u8 = "content/docs";
    // `zig build test` runs in the project root.
    const pages = load(t.io, arena_state.allocator(), "content/docs", &problem) catch |err| {
        std.debug.print("\ncontent/docs/{s}: {s}\n", .{ problem, @errorName(err) });
        return err;
    };
    try t.expect(pages.len > 0);
    // In reading order.
    for (pages[1..], pages[0 .. pages.len - 1]) |page, previous| {
        try t.expect(!readingOrder({}, page, previous));
    }
}

test "write: the generated file is valid Zig, whatever the text holds" {
    var out: std.Io.Writer.Allocating = .init(t.allocator);
    defer out.deinit();
    try write(&out.writer, &.{.{ .slug = "x", .meta = .{ .title = "Say \"hi\"", .section = .start, .order = 1, .body = "a \\ b\n```zig\nconst s = \"q\";\n```\n" } }});
    const source = try t.allocator.dupeSentinel(u8, out.written(), 0);
    defer t.allocator.free(source);
    var tree = try std.zig.Ast.parse(t.allocator, source, .{});
    defer tree.deinit(t.allocator);
    try t.expectEqual(@as(usize, 0), tree.errors.len);
}
