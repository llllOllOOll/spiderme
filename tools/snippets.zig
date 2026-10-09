//! Code blocks that come from real files.
//!
//! A page shows code of the example app by naming where it is, in the line
//! that opens the block, and leaving the block empty:
//!
//!     ```zig from=examples/posts/src/features/posts/routes.zig decl=build
//!     ```
//!
//!     ```html from=examples/posts/src/features/posts/views/PostCard.html
//!     ```
//!
//! `from` is a file, from the root of this repository. `decl` picks
//! declarations of a Zig file by name, with their doc comments: a function,
//! a constant, a test (by its text). Several, separated by commas or given
//! as several `decl=`, are shown in the order asked, a blank line between
//! them. A name with spaces or commas, as tests have, goes in quotes:
//!
//!     ```zig from=src/app_test.zig decl=run decl="the feed lists posts, newest first"
//!     ```
//!
//! Without `decl` the block is the whole file.
//!
//! The build puts the code in. A file or a declaration that is not there
//! stops it, so a page cannot show code the example no longer has; and the
//! example's own tests keep that code working.

const std = @import("std");

pub const Error = error{
    /// The block names a file that cannot be read.
    SnippetFileNotFound,
    /// The file has no top-level declaration with that name.
    SnippetDeclNotFound,
    /// A `from=` block has text in it: the build would throw it away.
    SnippetBlockNotEmpty,
    /// A `from=` block is never closed.
    SnippetBlockUnclosed,
} || std.mem.Allocator.Error;

/// Reads a file of the repository; null when it is not there.
pub const ReadFn = *const fn (ctx: *anyopaque, arena: std.mem.Allocator, path: []const u8) ?[]const u8;

/// `markdown` with every `from=` block filled in. `problem` receives what
/// could not be found (the file, or file and declaration).
pub fn expand(arena: std.mem.Allocator, markdown: []const u8, ctx: *anyopaque, read: ReadFn, problem: *[]const u8) Error![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var lines = std.mem.splitScalar(u8, markdown, '\n');
    var first = true;
    while (lines.next()) |line| {
        if (!first) try out.append(arena, '\n');
        first = false;

        const request = parseOpening(line) orelse {
            try out.appendSlice(arena, line);
            // An ordinary block: copy it as it is, so nothing inside it is
            // ever read as the opening of another.
            if (std.mem.startsWith(u8, line, "```")) {
                while (lines.next()) |inner| {
                    try out.append(arena, '\n');
                    try out.appendSlice(arena, inner);
                    if (std.mem.startsWith(u8, inner, "```")) break;
                }
            }
            continue;
        };

        problem.* = request.from;
        // The block must be empty up to its closing line.
        while (true) {
            const inner = lines.next() orelse return error.SnippetBlockUnclosed;
            if (std.mem.startsWith(u8, inner, "```")) break;
            if (std.mem.trim(u8, inner, " \t\r").len > 0) return error.SnippetBlockNotEmpty;
        }

        const source = read(ctx, arena, request.from) orelse return error.SnippetFileNotFound;
        const code = if (request.count == 0)
            std.mem.trim(u8, source, "\r\n")
        else
            try declarations(arena, source, request, problem);

        try out.print(arena, "```{s}\n{s}\n```", .{ request.language, code });
    }
    return out.items;
}

const max_decls = 8;

const Request = struct {
    language: []const u8,
    from: []const u8 = "",
    /// The names asked for; none for the whole file.
    names: [max_decls][]const u8 = undefined,
    count: usize = 0,

    fn add(self: *Request, name: []const u8) void {
        if (name.len == 0 or self.count == max_decls) return;
        self.names[self.count] = name;
        self.count += 1;
    }
};

/// The request in a line such as "```zig from=a/b.zig decl=x", or null for
/// any other line.
fn parseOpening(line: []const u8) ?Request {
    if (!std.mem.startsWith(u8, line, "```")) return null;
    const rest = std.mem.trim(u8, line[3..], " \t\r");
    const language_end = std.mem.indexOfAny(u8, rest, " \t") orelse rest.len;
    if (language_end == 0) return null;
    var request: Request = .{ .language = rest[0..language_end] };

    var i = language_end;
    while (i < rest.len) {
        while (i < rest.len and (rest[i] == ' ' or rest[i] == '\t')) i += 1;
        const eq = std.mem.indexOfScalarPos(u8, rest, i, '=') orelse break;
        const key = rest[i..eq];
        var value_start = eq + 1;
        var value_end: usize = undefined;
        const quoted = value_start < rest.len and rest[value_start] == '"';
        if (quoted) {
            value_start += 1;
            value_end = std.mem.indexOfScalarPos(u8, rest, value_start, '"') orelse rest.len;
            i = @min(value_end + 1, rest.len);
        } else {
            value_end = std.mem.indexOfAnyPos(u8, rest, value_start, " \t") orelse rest.len;
            i = value_end;
        }
        const value = rest[value_start..value_end];
        if (std.mem.eql(u8, key, "from")) {
            request.from = value;
        } else if (std.mem.eql(u8, key, "decl")) {
            if (quoted) {
                request.add(value);
            } else {
                var names = std.mem.tokenizeScalar(u8, value, ',');
                while (names.next()) |name| request.add(name);
            }
        }
    }
    return if (request.from.len == 0) null else request;
}

fn declarations(arena: std.mem.Allocator, source: []const u8, request: Request, problem: *[]const u8) Error![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    for (request.names[0..request.count]) |name| {
        const code = declaration(source, name) orelse {
            problem.* = try std.fmt.allocPrint(arena, "{s}: no top-level declaration named {s}", .{ request.from, name });
            return error.SnippetDeclNotFound;
        };
        if (out.items.len > 0) try out.appendSlice(arena, "\n\n");
        try out.appendSlice(arena, code);
    }
    return out.items;
}

/// The top-level declaration `name` of a Zig file formatted by `zig fmt`,
/// with the doc comments right above it: from its first line to the line
/// that closes it at the left margin.
pub fn declaration(source: []const u8, name: []const u8) ?[]const u8 {
    var start: usize = 0; // where the doc comments above the current line begin
    var in_docs = false;
    var offset: usize = 0;
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        const line_start = offset;
        offset += line.len + 1;

        if (std.mem.startsWith(u8, line, "///")) {
            if (!in_docs) start = line_start;
            in_docs = true;
            continue;
        }
        const from = if (in_docs) start else line_start;
        in_docs = false;
        if (!declares(line, name)) continue;

        // One line (`const a = 1;`, `fn f() void {}`), or up to the closing
        // line at the margin.
        const opening = std.mem.trimEnd(u8, line, " \r");
        if (std.mem.endsWith(u8, opening, ";") or std.mem.endsWith(u8, opening, "}")) {
            return source[from .. line_start + line.len];
        }
        var end = offset;
        while (lines.next()) |rest| {
            const rest_end = end + rest.len;
            if (std.mem.startsWith(u8, rest, "}")) return source[from..@min(rest_end, source.len)];
            end = rest_end + 1;
        }
        return null;
    }
    return null;
}

/// Whether a line at the left margin opens the declaration `name`.
fn declares(line: []const u8, name: []const u8) bool {
    var rest = line;
    if (std.mem.startsWith(u8, rest, "pub ")) rest = rest["pub ".len..];
    inline for (.{ "fn ", "const ", "var " }) |keyword| {
        if (std.mem.startsWith(u8, rest, keyword)) {
            const after = rest[keyword.len..];
            if (!std.mem.startsWith(u8, after, name)) return false;
            if (after.len == name.len) return true;
            return switch (after[name.len]) {
                '(', ' ', ':', '=' => true,
                else => false,
            };
        }
    }
    if (std.mem.startsWith(u8, rest, "test \"")) {
        const after = rest["test \"".len..];
        return std.mem.startsWith(u8, after, name) and after.len > name.len and after[name.len] == '"';
    }
    return false;
}

// ── tests ───────────────────────────────────────────────────────────────

const t = std.testing;

const sample =
    \\const std = @import("std");
    \\
    \\/// How many.
    \\pub const limit = 10;
    \\
    \\pub const Post = struct {
    \\    id: i64,
    \\};
    \\
    \\/// Lists them.
    \\/// Newest first.
    \\pub fn index(c: *Ctx) !Response {
    \\    if (c.ok()) {
    \\        return c.text("}", .{});
    \\    }
    \\    return error.NotFound;
    \\}
    \\
    \\fn indexOf() void {}
    \\
    \\// A plain comment is not part of what follows.
    \\fn load(c: *Ctx) !Post {
    \\    return c.find();
    \\}
    \\
    \\test "lists the posts" {
    \\    try index();
    \\}
    \\
;

test "declaration: a function with its doc comments, up to its closing line" {
    try t.expectEqualStrings(
        \\/// Lists them.
        \\/// Newest first.
        \\pub fn index(c: *Ctx) !Response {
        \\    if (c.ok()) {
        \\        return c.text("}", .{});
        \\    }
        \\    return error.NotFound;
        \\}
    , declaration(sample, "index").?);
}

test "declaration: constants, a type, a private function, a test by its text" {
    try t.expectEqualStrings("/// How many.\npub const limit = 10;", declaration(sample, "limit").?);
    try t.expectEqualStrings("pub const Post = struct {\n    id: i64,\n};", declaration(sample, "Post").?);
    try t.expectEqualStrings("fn load(c: *Ctx) !Post {\n    return c.find();\n}", declaration(sample, "load").?);
    try t.expectEqualStrings("fn indexOf() void {}", declaration(sample, "indexOf").?);
    try t.expectEqualStrings("test \"lists the posts\" {\n    try index();\n}", declaration(sample, "lists the posts").?);
    try t.expectEqualStrings("const std = @import(\"std\");", declaration(sample, "std").?);
}

test "declaration: a name that is only the start of another, or not there" {
    try t.expect(declaration(sample, "ind") == null);
    try t.expect(declaration(sample, "missing") == null);
    try t.expect(declaration(sample, "id") == null); // a field, not a declaration
}

const Files = struct {
    fn read(_: *anyopaque, _: std.mem.Allocator, path: []const u8) ?[]const u8 {
        if (std.mem.eql(u8, path, "app/posts.zig")) return sample;
        if (std.mem.eql(u8, path, "app/card.html")) return "<article>\n    { title }\n</article>\n";
        return null;
    }
};

fn expandSample(arena: std.mem.Allocator, markdown: []const u8, problem: *[]const u8) Error![]const u8 {
    var nothing: u8 = 0;
    return expand(arena, markdown, &nothing, Files.read, problem);
}

test "expand: a block gets the declarations it names, the rest of the page is untouched" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    var problem: []const u8 = "";
    const out = try expandSample(arena.allocator(),
        \\# Posts
        \\
        \\```zig from=app/posts.zig decl=load,limit
        \\```
        \\
        \\Text with `code` and a block of its own:
        \\
        \\```zig
        \\const x = 1; // ```zig from=app/missing.zig
        \\```
        \\
        \\```html from=app/card.html
        \\```
    , &problem);
    try t.expectEqualStrings(
        \\# Posts
        \\
        \\```zig
        \\fn load(c: *Ctx) !Post {
        \\    return c.find();
        \\}
        \\
        \\/// How many.
        \\pub const limit = 10;
        \\```
        \\
        \\Text with `code` and a block of its own:
        \\
        \\```zig
        \\const x = 1; // ```zig from=app/missing.zig
        \\```
        \\
        \\```html
        \\<article>
        \\    { title }
        \\</article>
        \\```
    , out);
}

test "expand: a file or a declaration that is not there stops the build and says which" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var problem: []const u8 = "";

    try t.expectError(error.SnippetFileNotFound, expandSample(a, "```zig from=app/gone.zig decl=x\n```", &problem));
    try t.expectEqualStrings("app/gone.zig", problem);

    try t.expectError(error.SnippetDeclNotFound, expandSample(a, "```zig from=app/posts.zig decl=index,renamed\n```", &problem));
    try t.expectEqualStrings("app/posts.zig: no top-level declaration named renamed", problem);

    try t.expectError(error.SnippetBlockNotEmpty, expandSample(a, "```zig from=app/posts.zig decl=load\nstale code\n```", &problem));
    try t.expectError(error.SnippetBlockUnclosed, expandSample(a, "```zig from=app/posts.zig decl=load\n", &problem));
}

test "expand: a test is asked for by its text, in quotes, next to other names" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    var problem: []const u8 = "";
    const out = try expandSample(arena.allocator(), "```zig from=app/posts.zig decl=limit decl=\"lists the posts\" decl=load\n```", &problem);
    try t.expectEqualStrings(
        \\```zig
        \\/// How many.
        \\pub const limit = 10;
        \\
        \\test "lists the posts" {
        \\    try index();
        \\}
        \\
        \\fn load(c: *Ctx) !Post {
        \\    return c.find();
        \\}
        \\```
    , out);

    try t.expectError(error.SnippetDeclNotFound, expandSample(arena.allocator(), "```zig from=app/posts.zig decl=\"lists the posts, all of them\"\n```", &problem));
    try t.expectEqualStrings("app/posts.zig: no top-level declaration named lists the posts, all of them", problem);
}
