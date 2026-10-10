//! Reads declarations and their doc comments out of Zig source text, for the
//! API reference (tools/api_reference.zig).
//!
//! It reads the text line by line, by indentation: enough for source that
//! went through `zig fmt`, which Spider's has. It keeps what a reference
//! needs: the name, the head of the declaration as written, the `///`
//! comment above it, the fields and the members of a type. It also keeps
//! the marks Spider uses to say a public name is not part of the API: a
//! `// internal:` comment above the name, or a `//!` header that starts
//! with `Internal:` for a whole file.

const std = @import("std");

pub const Field = struct {
    name: []const u8,
    /// What follows the name: `: []const u8 = "x"`, or `= 1` for an enum
    /// value with a number, or nothing for a plain enum value.
    rest: []const u8,
    /// The `///` text above the field, or "".
    doc: []const u8,
};

pub const Kind = enum {
    /// `fn name(...) T`
    function,
    /// `fn Name(...) type`: its members are those of the type it returns.
    type_function,
    /// `const Name = struct|union|enum|opaque { ... }`
    container,
    /// Any other `const` or `var`.
    constant,
};

pub const Decl = struct {
    name: []const u8,
    kind: Kind,
    public: bool,
    /// A `// internal:` comment sits above it.
    internal: bool,
    /// The head of the declaration as written, without its body: what a
    /// reader needs to call it. Several lines when the source has several.
    signature: []const u8,
    /// The `///` text above it, as Markdown, or "".
    doc: []const u8,
    /// For a `const` on one line: what is after the `=`, without the `;`.
    /// Empty otherwise. Used to follow `const X = @import("f.zig").Y;`.
    value: []const u8,
    fields: []const Field = &.{},
    members: []const Decl = &.{},
    /// Line of the declaration in its file, from 1.
    line: usize,
};

pub const File = struct {
    /// The `//!` text at the top, or "".
    header: []const u8,
    /// The header starts with `Internal:`.
    internal: bool,
    /// A file is a struct: it may have fields of its own.
    fields: []const Field,
    /// Top-level declarations, public or not, in source order.
    decls: []const Decl,

    pub fn find(self: File, name: []const u8) ?Decl {
        for (self.decls) |decl| {
            if (std.mem.eql(u8, decl.name, name)) return decl;
        }
        return null;
    }
};

pub fn parse(arena: std.mem.Allocator, source: []const u8) !File {
    var lines: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, source, '\n');
    while (it.next()) |line| try lines.append(arena, std.mem.trimEnd(u8, line, "\r"));

    var header: std.ArrayList(u8) = .empty;
    var after_header: usize = 0;
    for (lines.items) |line| {
        if (!std.mem.startsWith(u8, line, "//!")) break;
        try header.appendSlice(arena, stripDocPrefix(line, "//!"));
        try header.append(arena, '\n');
        after_header += 1;
    }
    const header_text = std.mem.trim(u8, header.items, "\n");

    var parser: Parser = .{ .arena = arena, .lines = lines.items };
    const body = try parser.container(after_header, lines.items.len, 0);
    return .{
        .header = header_text,
        .internal = std.mem.startsWith(u8, header_text, "Internal:"),
        .fields = body.fields,
        .decls = body.decls,
    };
}

const Body = struct { fields: []const Field, decls: []const Decl };

const Parser = struct {
    arena: std.mem.Allocator,
    lines: []const []const u8,

    /// The declarations and fields written at `indent` between two lines.
    fn container(self: *Parser, start: usize, end: usize, indent: usize) std.mem.Allocator.Error!Body {
        var decls: std.ArrayList(Decl) = .empty;
        var fields: std.ArrayList(Field) = .empty;
        var i = start;
        while (i < end) {
            const line = self.lines[i];
            const text = std.mem.trimStart(u8, line, " ");
            if (text.len == 0 or std.mem.startsWith(u8, text, "//") or indentOf(line) != indent) {
                i += 1;
                continue;
            }
            const last = self.statementEnd(i, end, indent);
            if (try self.declaration(i, last, indent)) |decl| {
                try decls.append(self.arena, decl);
            } else if (fieldName(text)) |name| {
                try fields.append(self.arena, .{
                    .name = name,
                    .rest = try self.fieldRest(i, last, name.len),
                    .doc = try self.docAbove(i),
                });
            }
            i = last + 1;
        }
        return .{ .fields = fields.items, .decls = decls.items };
    }

    /// The last line of the statement that starts at line `i`: the line
    /// itself when it is complete, or the next line back at the same
    /// indentation (the one that closes what the first line opened).
    fn statementEnd(self: *Parser, i: usize, end: usize, indent: usize) usize {
        const first = code(self.lines[i]);
        if (complete(first)) return i;
        var j = i + 1;
        while (j < end) : (j += 1) {
            const line = self.lines[j];
            const text = std.mem.trimStart(u8, line, " ");
            if (text.len == 0 or std.mem.startsWith(u8, text, "//")) continue;
            if (indentOf(line) <= indent) {
                // `} else {`, `},` and the like close and go on; a line that
                // closes for good ends with `;`, `,` or `}`.
                const closing = code(line);
                if (complete(closing) or std.mem.endsWith(u8, closing, "}")) return j;
            }
        }
        return end - 1;
    }

    fn declaration(self: *Parser, first: usize, last: usize, indent: usize) !?Decl {
        var text = std.mem.trimStart(u8, self.lines[first], " ");
        const public = std.mem.startsWith(u8, text, "pub ");
        if (public) text = text[4..];
        inline for (.{ "inline ", "export ", "extern ", "noinline " }) |word| {
            if (std.mem.startsWith(u8, text, word)) text = text[word.len..];
        }
        // `extern "c" fn`
        if (std.mem.startsWith(u8, text, "\"")) {
            const close = std.mem.indexOfScalarPos(u8, text, 1, '"') orelse return null;
            text = std.mem.trimStart(u8, text[close + 1 ..], " ");
        }

        const is_fn = std.mem.startsWith(u8, text, "fn ");
        const is_const = std.mem.startsWith(u8, text, "const ");
        const is_var = std.mem.startsWith(u8, text, "var ");
        if (!is_fn and !is_const and !is_var) return null;
        const after = text[if (is_fn) 3 else if (is_const) 6 else 4..];
        const name = identifier(after) orelse return null;

        var decl: Decl = .{
            .name = name,
            .kind = .constant,
            .public = public,
            .internal = self.internalAbove(first),
            .signature = "",
            .doc = try self.docAbove(first),
            .value = "",
            .line = first + 1,
        };

        if (is_fn) {
            const head = try self.join(first, last, indent);
            const brace = bodyBrace(head);
            decl.signature = std.mem.trimEnd(u8, if (brace) |at| head[0..at] else head, " ;");
            decl.kind = .function;
            if (std.mem.endsWith(u8, decl.signature, " type")) {
                decl.kind = .type_function;
                if (self.returnedContainer(first, last, indent)) |inner| {
                    const body = try self.container(inner.start, inner.end, inner.indent);
                    decl.fields = body.fields;
                    decl.members = body.decls;
                }
            }
            return decl;
        }

        const first_line = std.mem.trimStart(u8, code(self.lines[first]), " ");
        if (containerHead(first_line)) {
            decl.kind = .container;
            // `= struct {` keeps `= struct`; `= error{` keeps `= error`.
            decl.signature = std.mem.trimEnd(u8, first_line[0 .. first_line.len - 1], " ");
            if (last > first) {
                const body = try self.container(first + 1, last, indent + 4);
                decl.fields = body.fields;
                decl.members = body.decls;
            }
            return decl;
        }

        if (last == first) {
            decl.signature = std.mem.trimEnd(u8, first_line, ";");
            if (std.mem.indexOf(u8, first_line, " = ")) |eq| {
                decl.value = std.mem.trimEnd(u8, first_line[eq + 3 ..], ";");
            }
        } else {
            decl.signature = try std.fmt.allocPrint(self.arena, "{s} ...", .{first_line});
        }
        return decl;
    }

    const Range = struct { start: usize, end: usize, indent: usize };

    /// Inside a `fn Name(...) type`, the lines of the `return struct { ... }`.
    fn returnedContainer(self: *Parser, first: usize, last: usize, indent: usize) ?Range {
        var i = first + 1;
        while (i < last) : (i += 1) {
            const line = self.lines[i];
            const text = std.mem.trimStart(u8, code(line), " ");
            if (indentOf(line) != indent + 4 or !std.mem.startsWith(u8, text, "return ")) continue;
            if (!containerHead(text)) continue;
            var j = i + 1;
            while (j < last) : (j += 1) {
                const closing = self.lines[j];
                if (indentOf(closing) == indent + 4 and std.mem.startsWith(u8, std.mem.trimStart(u8, closing, " "), "}")) break;
            }
            return .{ .start = i + 1, .end = j, .indent = indent + 8 };
        }
        return null;
    }

    /// The `///` lines right above line `i`, as text.
    fn docAbove(self: *Parser, i: usize) ![]const u8 {
        var first = i;
        while (first > 0 and std.mem.startsWith(u8, std.mem.trimStart(u8, self.lines[first - 1], " "), "///")) first -= 1;
        if (first == i) return "";
        var out: std.ArrayList(u8) = .empty;
        for (self.lines[first..i]) |line| {
            try out.appendSlice(self.arena, stripDocPrefix(std.mem.trimStart(u8, line, " "), "///"));
            try out.append(self.arena, '\n');
        }
        return std.mem.trim(u8, out.items, "\n");
    }

    /// A plain comment block above line `i` with a line `// internal: ...`.
    fn internalAbove(self: *Parser, i: usize) bool {
        var j = i;
        while (j > 0) {
            j -= 1;
            const text = std.mem.trimStart(u8, self.lines[j], " ");
            if (!std.mem.startsWith(u8, text, "//") or std.mem.startsWith(u8, text, "///")) return false;
            if (std.mem.startsWith(u8, text, "// internal:")) return true;
        }
        return false;
    }

    /// Lines `first..last` as one text, each without the first `indent`
    /// spaces.
    fn join(self: *Parser, first: usize, last: usize, indent: usize) ![]const u8 {
        var out: std.ArrayList(u8) = .empty;
        for (self.lines[first .. last + 1], 0..) |line, n| {
            // Only the head matters to a function: stop at its body.
            if (n > 0) try out.append(self.arena, '\n');
            try out.appendSlice(self.arena, if (line.len >= indent) line[indent..] else std.mem.trimStart(u8, line, " "));
            if (bodyBrace(out.items) != null) break;
        }
        return out.items;
    }

    /// What follows the name of a field, on one line.
    fn fieldRest(self: *Parser, first: usize, last: usize, name_len: usize) ![]const u8 {
        const text = std.mem.trimStart(u8, code(self.lines[first]), " ");
        var out: std.ArrayList(u8) = .empty;
        try out.appendSlice(self.arena, std.mem.trim(u8, text[name_len..], " "));
        if (last > first) {
            // A default written over several lines: say there is one.
            if (std.mem.endsWith(u8, out.items, "{") or std.mem.endsWith(u8, out.items, "(")) {
                try out.appendSlice(self.arena, " ... ");
                try out.appendSlice(self.arena, std.mem.trim(u8, code(self.lines[last]), " ,"));
            }
        }
        return std.mem.trimEnd(u8, out.items, ", ");
    }
};

fn indentOf(line: []const u8) usize {
    return line.len - std.mem.trimStart(u8, line, " ").len;
}

/// `/// text` gives `text`; `///` gives ``. One space after the marker is
/// the separator, the rest is the text's own (an indented example).
fn stripDocPrefix(line: []const u8, comptime marker: []const u8) []const u8 {
    const rest = line[marker.len..];
    return if (rest.len > 0 and rest[0] == ' ') rest[1..] else rest;
}

/// A line without the `// comment` at its end, and without the spaces
/// before it. Quotes are followed, so the `//` of "https://x" stays.
fn code(line: []const u8) []const u8 {
    var in_string = false;
    var i: usize = 0;
    while (i < line.len) : (i += 1) {
        const ch = line[i];
        if (in_string) {
            if (ch == '\\') i += 1 else if (ch == '"') in_string = false;
        } else if (ch == '"') {
            in_string = true;
        } else if (ch == '\\' and i + 1 < line.len and line[i + 1] == '\\') {
            // A multi-line string literal: the rest of the line is its text.
            break;
        } else if (ch == '/' and i + 1 < line.len and line[i + 1] == '/') {
            return std.mem.trimEnd(u8, line[0..i], " ");
        }
    }
    return std.mem.trimEnd(u8, line, " ");
}

/// A line that ends its statement: `...;` or `...,` (a field), or `{}`.
fn complete(line: []const u8) bool {
    return std.mem.endsWith(u8, line, ";") or std.mem.endsWith(u8, line, ",") or std.mem.endsWith(u8, line, "{}");
}

fn identifier(text: []const u8) ?[]const u8 {
    if (text.len > 1 and text[0] == '@' and text[1] == '"') {
        const close = std.mem.indexOfScalarPos(u8, text, 2, '"') orelse return null;
        return text[0 .. close + 1];
    }
    var end: usize = 0;
    while (end < text.len and (std.ascii.isAlphanumeric(text[end]) or text[end] == '_')) end += 1;
    return if (end == 0) null else text[0..end];
}

/// The name of a field when the line declares one: `name: T,`, `name,` or
/// `name = 1,`.
fn fieldName(text: []const u8) ?[]const u8 {
    inline for (.{ "test ", "test{", "comptime ", "usingnamespace ", "defer ", "errdefer ", "return ", "if ", "for ", "while ", "switch ", "try ", "_ = ", "}", ")", "]", "." }) |word| {
        if (std.mem.startsWith(u8, text, word)) return null;
    }
    const name = identifier(text) orelse return null;
    const rest = std.mem.trimStart(u8, text[name.len..], " ");
    if (rest.len == 0) return null;
    return if (rest[0] == ':' or rest[0] == ',' or rest[0] == '=') name else null;
}

/// `const X = struct {`, `= union(enum) {`, `= enum(u8) {`, `return struct {`...
fn containerHead(line: []const u8) bool {
    if (!std.mem.endsWith(u8, line, "{")) return false;
    const at = if (std.mem.indexOf(u8, line, " = ")) |eq| eq + 3 else if (std.mem.startsWith(u8, line, "return ")) 7 else return false;
    var value = line[at..];
    inline for (.{ "extern ", "packed " }) |word| {
        if (std.mem.startsWith(u8, value, word)) value = value[word.len..];
    }
    inline for (.{ "struct", "union", "enum", "opaque", "error" }) |word| {
        if (std.mem.startsWith(u8, value, word)) {
            const next = if (value.len > word.len) value[word.len] else ' ';
            if (next == ' ' or next == '(' or next == '{') return true;
        }
    }
    return false;
}

/// Where the body of a function starts in its head: the first `{` outside
/// parentheses that follows a space (`error{A}!void` has none before it).
fn bodyBrace(head: []const u8) ?usize {
    var depth: usize = 0;
    for (head, 0..) |ch, i| {
        switch (ch) {
            '(', '[' => depth += 1,
            ')', ']' => depth -|= 1,
            '{' => if (depth == 0 and i > 0 and head[i - 1] == ' ') return i,
            else => {},
        }
    }
    return null;
}

// ── tests ───────────────────────────────────────────────────────────────

const t = std.testing;

fn parsed(arena: *std.heap.ArenaAllocator, source: []const u8) !File {
    return parse(arena.allocator(), source);
}

test "a function: name, head without the body, doc comment" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const file = try parsed(&arena,
        \\const std = @import("std");
        \\
        \\/// Adds two numbers.
        \\///
        \\/// Never fails.
        \\pub fn add(a: i32, b: i32) i32 {
        \\    return a + b;
        \\}
        \\
        \\fn hidden() void {}
    );
    try t.expectEqual(@as(usize, 3), file.decls.len);
    const add = file.find("add").?;
    try t.expect(add.public);
    try t.expectEqual(Kind.function, add.kind);
    try t.expectEqualStrings("pub fn add(a: i32, b: i32) i32", add.signature);
    try t.expectEqualStrings("Adds two numbers.\n\nNever fails.", add.doc);
    try t.expectEqual(@as(usize, 6), add.line);
    try t.expect(!file.find("hidden").?.public);
    try t.expectEqualStrings("fn hidden() void", file.find("hidden").?.signature);
    try t.expectEqualStrings("@import(\"std\")", file.find("std").?.value);
}

test "a head over several lines, and an error set in the return type" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const file = try parsed(&arena,
        \\pub fn setCookie(
        \\    self: *Ctx,
        \\    name: []const u8,
        \\) ![]const u8 {
        \\    return name;
        \\}
        \\
        \\pub fn check(sql: []const u8) error{UseBegin}!void {
        \\    _ = sql;
        \\}
    );
    try t.expectEqualStrings("pub fn setCookie(\n    self: *Ctx,\n    name: []const u8,\n) ![]const u8", file.find("setCookie").?.signature);
    try t.expectEqualStrings("pub fn check(sql: []const u8) error{UseBegin}!void", file.find("check").?.signature);
}

test "a struct: fields with their docs, methods, nested types" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const file = try parsed(&arena,
        \\/// The options.
        \\pub const Options = struct {
        \\    /// How many.
        \\    count: usize = 5,
        \\    name: []const u8,
        \\    _hidden: bool = false,
        \\    headers: []const [2][]const u8 = &.{
        \\        .{ "a", "b" },
        \\    },
        \\
        \\    pub const Mode = enum { fast, slow };
        \\
        \\    /// Makes one.
        \\    pub fn init(name: []const u8) Options {
        \\        return .{ .name = name };
        \\    }
        \\
        \\    fn private(self: Options) void {
        \\        _ = self;
        \\    }
        \\};
    );
    const options = file.find("Options").?;
    try t.expectEqual(Kind.container, options.kind);
    try t.expectEqualStrings("pub const Options = struct", options.signature);
    try t.expectEqualStrings("The options.", options.doc);
    try t.expectEqual(@as(usize, 4), options.fields.len);
    try t.expectEqualStrings("count", options.fields[0].name);
    try t.expectEqualStrings(": usize = 5", options.fields[0].rest);
    try t.expectEqualStrings("How many.", options.fields[0].doc);
    try t.expectEqualStrings(": []const u8", options.fields[1].rest);
    try t.expectEqualStrings("_hidden", options.fields[2].name);
    try t.expectEqualStrings(": []const [2][]const u8 = &.{ ... }", options.fields[3].rest);
    try t.expectEqual(@as(usize, 3), options.members.len);
    try t.expectEqualStrings("Mode", options.members[0].name);
    try t.expectEqualStrings("pub const Mode = enum { fast, slow }", options.members[0].signature);
    try t.expectEqualStrings("init", options.members[1].name);
    try t.expectEqualStrings("pub fn init(name: []const u8) Options", options.members[1].signature);
    try t.expect(!options.members[2].public);
}

test "an enum and a union: their values are fields" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const file = try parsed(&arena,
        \\pub const Kind = enum(u8) {
        \\    /// The first.
        \\    one = 1,
        \\    two,
        \\};
        \\
        \\pub const Value = union(enum) {
        \\    text: []const u8,
        \\    none,
        \\};
    );
    const kind = file.find("Kind").?;
    try t.expectEqualStrings("pub const Kind = enum(u8)", kind.signature);
    try t.expectEqual(@as(usize, 2), kind.fields.len);
    try t.expectEqualStrings("= 1", kind.fields[0].rest);
    try t.expectEqualStrings("The first.", kind.fields[0].doc);
    try t.expectEqualStrings("", kind.fields[1].rest);
    try t.expectEqual(@as(usize, 2), file.find("Value").?.fields.len);
}

test "a function that returns a type: the members of that type" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const file = try parsed(&arena,
        \\/// A typed list.
        \\pub fn List(comptime T: type) type {
        \\    const helper = 1;
        \\    _ = helper;
        \\    return struct {
        \\        items: []T,
        \\
        \\        /// How many.
        \\        pub fn len(self: @This()) usize {
        \\            return self.items.len;
        \\        }
        \\    };
        \\}
        \\
        \\pub fn after() void {}
    );
    const list = file.find("List").?;
    try t.expectEqual(Kind.type_function, list.kind);
    try t.expectEqualStrings("pub fn List(comptime T: type) type", list.signature);
    try t.expectEqual(@as(usize, 1), list.fields.len);
    try t.expectEqual(@as(usize, 1), list.members.len);
    try t.expectEqualStrings("len", list.members[0].name);
    try t.expectEqualStrings("How many.", list.members[0].doc);
    try t.expect(file.find("after") != null);
}

test "constants: one line keeps its value, several lines do not" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const file = try parsed(&arena,
        \\pub const Ctx = @import("core/context.zig").Ctx;
        \\pub const pg = @import("spider_pg");
        \\pub const policy = rbac.policy;
        \\pub const max: usize = 10;
        \\pub var options: Options = .{};
        \\pub const table = [_]u8{
        \\    1,
        \\    2,
        \\};
        \\pub const text =
        \\    \\one
        \\    \\two
        \\;
        \\pub fn last() void {}
    );
    try t.expectEqualStrings("@import(\"core/context.zig\").Ctx", file.find("Ctx").?.value);
    try t.expectEqualStrings("@import(\"spider_pg\")", file.find("pg").?.value);
    try t.expectEqualStrings("rbac.policy", file.find("policy").?.value);
    try t.expectEqualStrings("pub const max: usize = 10", file.find("max").?.signature);
    try t.expectEqualStrings("pub var options: Options = .{}", file.find("options").?.signature);
    try t.expectEqualStrings("pub const table = [_]u8{ ...", file.find("table").?.signature);
    try t.expectEqualStrings("", file.find("table").?.value);
    try t.expectEqualStrings("pub const text = ...", file.find("text").?.signature);
    try t.expect(file.find("last") != null);
}

test "internal: a note above a name, or the header of the file" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const file = try parsed(&arena,
        \\//! What the file is for.
        \\//! Second line.
        \\
        \\// internal: the server calls it;
        \\// apps do not.
        \\pub fn plumbing() void {}
        \\
        \\// just a remark
        \\pub fn open() void {}
        \\
        \\/// Documented.
        \\pub fn documented() void {}
    );
    try t.expectEqualStrings("What the file is for.\nSecond line.", file.header);
    try t.expect(!file.internal);
    try t.expect(file.find("plumbing").?.internal);
    try t.expect(!file.find("open").?.internal);
    try t.expect(!file.find("documented").?.internal);
    try t.expectEqualStrings("", file.find("plumbing").?.doc);

    const whole = try parsed(&arena, "//! Internal: plumbing of the router.\n\npub fn a() void {}\n");
    try t.expect(whole.internal);
}

test "a doc comment keeps its code blocks and its indentation" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const file = try parsed(&arena,
        \\/// Sends it.
        \\///
        \\/// ```zig
        \\/// try send(.{
        \\///     .to = "a",
        \\/// });
        \\/// ```
        \\pub fn send() void {}
    );
    try t.expectEqualStrings("Sends it.\n\n```zig\ntry send(.{\n    .to = \"a\",\n});\n```", file.find("send").?.doc);
}

test "tests, comptime blocks and what is inside function bodies are not declarations" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const file = try parsed(&arena,
        \\pub fn outer() void {
        \\    const W = struct {
        \\        pub fn call() void {}
        \\    };
        \\    _ = W;
        \\}
        \\
        \\test "something" {
        \\    const x = 1;
        \\    _ = x;
        \\}
        \\
        \\comptime {
        \\    _ = outer;
        \\}
        \\
        \\pub fn end() void {}
    );
    try t.expectEqual(@as(usize, 2), file.decls.len);
    try t.expectEqualStrings("outer", file.decls[0].name);
    try t.expectEqualStrings("end", file.decls[1].name);
    try t.expectEqual(@as(usize, 0), file.fields.len);
}

test "a file that is a struct has fields of its own" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const file = try parsed(&arena,
        \\const std = @import("std");
        \\
        \\/// The handler for h1.
        \\h1: Handler = Default.h1,
        \\link: Handler = Default.link,
        \\
        \\pub const Handler = fn (u8) u8;
    );
    try t.expectEqual(@as(usize, 2), file.fields.len);
    try t.expectEqualStrings("h1", file.fields[0].name);
    try t.expectEqualStrings("The handler for h1.", file.fields[0].doc);
    try t.expectEqualStrings("pub const Handler = fn (u8) u8", file.find("Handler").?.signature);
}

test "a comment at the end of a line does not hide where the statement ends" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const file = try parsed(&arena,
        \\const nonce_len = 16; // 128 bits
        \\const url = "https://example.com"; // not a comment inside the quotes
        \\
        \\/// The first.
        \\pub const A = struct { // why it exists
        \\    x: u8, // a field
        \\};
        \\
        \\pub fn b() void {} // trailing
    );
    try t.expectEqual(@as(usize, 4), file.decls.len);
    try t.expectEqualStrings("\"https://example.com\"", file.find("url").?.value);
    try t.expectEqualStrings("pub const A = struct", file.find("A").?.signature);
    try t.expectEqualStrings(": u8", file.find("A").?.fields[0].rest);
    try t.expect(file.find("b") != null);
}

test "an error set: its errors are fields, with their comments" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const file = try parsed(&arena,
        \\/// What it fails with.
        \\pub const Error = error{
        \\    /// No code.
        \\    CodeMissing,
        \\    CodeRejected,
        \\};
        \\
        \\pub const Small = error{ A, B };
    );
    const set = file.find("Error").?;
    try t.expectEqual(Kind.container, set.kind);
    try t.expectEqualStrings("pub const Error = error", set.signature);
    try t.expectEqual(@as(usize, 2), set.fields.len);
    try t.expectEqualStrings("CodeMissing", set.fields[0].name);
    try t.expectEqualStrings("No code.", set.fields[0].doc);
    try t.expectEqualStrings("pub const Small = error{ A, B }", file.find("Small").?.signature);
}
