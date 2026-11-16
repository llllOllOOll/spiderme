//! Colours for the code blocks of the pages, made on the server.
//!
//! A fenced block's language (```zig, ```bash, ...) picks a small lexer
//! that wraps the parts of each line in `<span class="tok-…">`: keywords,
//! strings, comments, numbers, function names, types, builtins, tags and
//! attributes, template code. Whatever a lexer does not know stays plain
//! text, so a block never loses a character; the stylesheet colours the
//! classes for the light and the dark theme. No JavaScript.

const std = @import("std");

pub const Lang = enum { zig, bash, sql, html, json, yaml, css, text };

pub fn langOf(name: []const u8) Lang {
    if (std.mem.eql(u8, name, "sh") or std.mem.eql(u8, name, "shell")) return .bash;
    return std.meta.stringToEnum(Lang, name) orelse .text;
}

/// `code` is the block as the Markdown renderer gives it: already escaped.
/// The result is escaped too, with the spans added.
pub fn highlight(arena: std.mem.Allocator, lang: Lang, escaped: []const u8) ![]const u8 {
    if (lang == .text) return escaped;
    const src = try unescape(arena, escaped);
    var out: Out = .{ .arena = arena };
    switch (lang) {
        .zig => try zig(&out, src),
        .bash => try bash(&out, src),
        .sql => try sql(&out, src),
        .html => try html(&out, src),
        .json => try json(&out, src),
        .yaml => try yaml(&out, src),
        .css => try css(&out, src),
        .text => unreachable,
    }
    return out.buf.items;
}

const Out = struct {
    arena: std.mem.Allocator,
    buf: std.ArrayList(u8) = .empty,

    fn plain(self: *Out, text: []const u8) !void {
        for (text) |ch| switch (ch) {
            '&' => try self.buf.appendSlice(self.arena, "&amp;"),
            '<' => try self.buf.appendSlice(self.arena, "&lt;"),
            '>' => try self.buf.appendSlice(self.arena, "&gt;"),
            '"' => try self.buf.appendSlice(self.arena, "&quot;"),
            '\'' => try self.buf.appendSlice(self.arena, "&#39;"),
            else => try self.buf.append(self.arena, ch),
        };
    }

    fn tok(self: *Out, class: []const u8, text: []const u8) !void {
        if (text.len == 0) return;
        try self.buf.appendSlice(self.arena, "<span class=\"tok-");
        try self.buf.appendSlice(self.arena, class);
        try self.buf.appendSlice(self.arena, "\">");
        try self.plain(text);
        try self.buf.appendSlice(self.arena, "</span>");
    }
};

fn unescape(arena: std.mem.Allocator, s: []const u8) ![]const u8 {
    if (std.mem.indexOfScalar(u8, s, '&') == null) return s;
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    outer: while (i < s.len) {
        if (s[i] == '&') {
            for ([_][2][]const u8{ .{ "&amp;", "&" }, .{ "&lt;", "<" }, .{ "&gt;", ">" }, .{ "&quot;", "\"" }, .{ "&#39;", "'" }, .{ "&#x27;", "'" } }) |pair| {
                if (std.mem.startsWith(u8, s[i..], pair[0])) {
                    try out.appendSlice(arena, pair[1]);
                    i += pair[0].len;
                    continue :outer;
                }
            }
        }
        try out.append(arena, s[i]);
        i += 1;
    }
    return out.items;
}

fn isIdentStart(ch: u8) bool {
    return std.ascii.isAlphabetic(ch) or ch == '_';
}
fn isIdent(ch: u8) bool {
    return std.ascii.isAlphanumeric(ch) or ch == '_';
}
fn identEnd(s: []const u8, start: usize) usize {
    var j = start;
    while (j < s.len and isIdent(s[j])) j += 1;
    return j;
}
fn numberEnd(s: []const u8, start: usize) usize {
    var j = start;
    while (j < s.len and (std.ascii.isAlphanumeric(s[j]) or s[j] == '_' or (s[j] == '.' and j + 1 < s.len and std.ascii.isDigit(s[j + 1])))) j += 1;
    return j;
}
/// The end of a string opened at `start` by `quote`, the closing quote
/// included; a backslash escapes the next character. Stops at the line end.
fn stringEnd(s: []const u8, start: usize, quote: u8) usize {
    var j = start + 1;
    while (j < s.len and s[j] != '\n') : (j += 1) {
        if (s[j] == '\\') {
            j += 1;
            continue;
        }
        if (s[j] == quote) return j + 1;
    }
    return j;
}
fn lineEnd(s: []const u8, start: usize) usize {
    return std.mem.indexOfScalarPos(u8, s, start, '\n') orelse s.len;
}
fn nextNonSpace(s: []const u8, start: usize) ?u8 {
    var j = start;
    while (j < s.len and (s[j] == ' ' or s[j] == '\t')) j += 1;
    return if (j < s.len) s[j] else null;
}
fn isOneOf(word: []const u8, comptime list: []const []const u8) bool {
    inline for (list) |item| if (std.mem.eql(u8, word, item)) return true;
    return false;
}

const zig_keywords = [_][]const u8{
    "addrspace", "align",    "allowzero", "and",         "anyframe", "anytype",  "asm",        "break",       "callconv",    "catch",
    "comptime",  "const",    "continue",  "defer",       "else",     "enum",     "errdefer",   "error",       "export",      "extern",
    "fn",        "for",      "if",        "inline",      "linksection", "noalias", "noinline", "nosuspend",   "opaque",      "or",
    "orelse",    "packed",   "pub",       "resume",      "return",   "struct",   "suspend",    "switch",      "test",        "threadlocal",
    "try",       "union",    "unreachable", "usingnamespace", "var", "volatile", "while",      "true",        "false",       "null",
    "undefined",
};
const zig_types = [_][]const u8{
    "u8", "u16", "u32", "u64", "u128", "usize", "i8", "i16", "i32", "i64", "i128", "isize", "f16", "f32", "f64", "f128",
    "bool", "void", "type", "anyerror", "noreturn", "comptime_int", "comptime_float", "anyopaque",
};

fn zig(out: *Out, s: []const u8) !void {
    var i: usize = 0;
    var plain_from: usize = 0;
    while (i < s.len) {
        const ch = s[i];
        var class: ?[]const u8 = null;
        var end = i + 1;
        if (ch == '/' and i + 1 < s.len and s[i + 1] == '/') {
            class = "c";
            end = lineEnd(s, i);
        } else if (ch == '\\' and i + 1 < s.len and s[i + 1] == '\\') {
            class = "s";
            end = lineEnd(s, i);
        } else if (ch == '"' or ch == '\'') {
            class = "s";
            end = stringEnd(s, i, ch);
        } else if (ch == '@' and i + 1 < s.len and isIdentStart(s[i + 1])) {
            class = "b";
            end = identEnd(s, i + 1);
        } else if (ch == '@' and i + 1 < s.len and s[i + 1] == '"') {
            end = stringEnd(s, i + 1, '"');
        } else if (std.ascii.isDigit(ch) and (i == 0 or !isIdent(s[i - 1]))) {
            class = "n";
            end = numberEnd(s, i);
        } else if (isIdentStart(ch) and (i == 0 or !isIdent(s[i - 1]))) {
            end = identEnd(s, i);
            const word = s[i..end];
            if (isOneOf(word, &zig_keywords)) {
                class = "k";
            } else if (isOneOf(word, &zig_types) or std.ascii.isUpper(word[0])) {
                class = "t";
            } else if (nextNonSpace(s, end) == '(') {
                class = "f";
            }
        }
        if (class) |cls| {
            try out.plain(s[plain_from..i]);
            try out.tok(cls, s[i..end]);
            plain_from = end;
        }
        i = end;
    }
    try out.plain(s[plain_from..]);
}

const bash_keywords = [_][]const u8{ "if", "then", "else", "elif", "fi", "for", "in", "do", "done", "while", "case", "esac", "function", "export", "local", "return" };

fn bash(out: *Out, s: []const u8) !void {
    var i: usize = 0;
    var plain_from: usize = 0;
    var command_next = true; // the first word of a line, or after | && ;
    while (i < s.len) {
        const ch = s[i];
        var class: ?[]const u8 = null;
        var end = i + 1;
        if (ch == '#' and (i == 0 or s[i - 1] == ' ' or s[i - 1] == '\n' or s[i - 1] == '\t')) {
            class = "c";
            end = lineEnd(s, i);
        } else if (ch == '"' or ch == '\'') {
            class = "s";
            end = stringEnd(s, i, ch);
            command_next = false;
        } else if (ch == '$' and i + 1 < s.len and (isIdentStart(s[i + 1]) or s[i + 1] == '{')) {
            class = "b";
            if (s[i + 1] == '{') {
                end = (std.mem.indexOfScalarPos(u8, s, i, '}') orelse i + 1) + 1;
            } else end = identEnd(s, i + 1);
        } else if (ch == '\n' or ch == '|' or ch == ';' or ch == '&') {
            command_next = true;
        } else if (ch == '-' and (i == 0 or s[i - 1] == ' ') and !command_next) {
            class = "a";
            end = i;
            while (end < s.len and s[end] != ' ' and s[end] != '\n' and s[end] != '=') end += 1;
        } else if (ch != ' ' and ch != '\t' and ch != '\\' and (i == 0 or s[i - 1] == ' ' or s[i - 1] == '\n' or s[i - 1] == '\t' or s[i - 1] == '|' or s[i - 1] == '(')) {
            end = i;
            while (end < s.len and s[end] != ' ' and s[end] != '\n' and s[end] != ';' and s[end] != '|' and s[end] != ')') end += 1;
            if (end == i) end = i + 1; // a lone `)` or `|`: plain text
            const word = s[i..end];
            if (end == i + 1 and !isIdent(word[0]) and word[0] != '.' and word[0] != '/' and word[0] != '~') {
                // punctuation, left plain
            } else if (isOneOf(word, &bash_keywords)) {
                class = "k";
            } else if (command_next and std.mem.indexOfScalar(u8, word, '=') == null) {
                class = "f";
                command_next = false;
            } else if (command_next) {
                // VAR=value before a command: the command is still to come
            } else if (std.ascii.isDigit(word[0])) {
                class = "n";
            }
        }
        if (class) |cls| {
            try out.plain(s[plain_from..i]);
            try out.tok(cls, s[i..end]);
            plain_from = end;
        }
        i = end;
    }
    try out.plain(s[plain_from..]);
}

const sql_keywords = [_][]const u8{
    "select", "from",    "where",      "and",     "or",       "not",    "null",     "is",      "in",      "insert", "into",    "values",
    "update", "set",     "delete",     "create",  "table",    "index",  "unique",   "primary", "key",     "foreign", "references", "on",
    "drop",   "alter",   "add",        "column",  "if",       "exists", "default",  "order",   "by",      "asc",    "desc",    "limit",
    "offset", "join",    "left",       "inner",   "outer",    "as",     "group",    "having",  "returning", "begin", "commit", "rollback",
    "check",  "constraint", "cascade", "integer", "int",      "bigint", "text",     "varchar", "boolean", "timestamp", "timestamptz", "serial",
    "bigserial", "real", "uuid",       "jsonb",   "now",      "true",   "false",    "like",    "ilike",   "count",  "distinct", "with",
    "top",    "cast",    "go",         "nvarchar", "identity", "case",  "when",     "then",    "else",    "end",
};

fn sql(out: *Out, s: []const u8) !void {
    var i: usize = 0;
    var plain_from: usize = 0;
    var lower: [32]u8 = undefined;
    while (i < s.len) {
        const ch = s[i];
        var class: ?[]const u8 = null;
        var end = i + 1;
        if (ch == '-' and i + 1 < s.len and s[i + 1] == '-') {
            class = "c";
            end = lineEnd(s, i);
        } else if (ch == '\'') {
            class = "s";
            end = stringEnd(s, i, '\'');
        } else if (std.ascii.isDigit(ch) and (i == 0 or !isIdent(s[i - 1]))) {
            class = "n";
            end = numberEnd(s, i);
        } else if ((ch == '$' or ch == '@') and i + 1 < s.len and isIdent(s[i + 1])) {
            class = "b";
            end = identEnd(s, i + 1);
        } else if (isIdentStart(ch) and (i == 0 or !isIdent(s[i - 1]))) {
            end = identEnd(s, i);
            const word = s[i..end];
            if (word.len <= lower.len and isOneOf(std.ascii.lowerString(&lower, word), &sql_keywords)) class = "k";
        }
        if (class) |cls| {
            try out.plain(s[plain_from..i]);
            try out.tok(cls, s[i..end]);
            plain_from = end;
        }
        i = end;
    }
    try out.plain(s[plain_from..]);
}

const template_keywords = [_][]const u8{ "if", "else", "for", "extends", "block", "include", "switch", "case", "default" };

/// HTML and Spider's templates: tags, attributes, values, comments, the
/// `{ expression }` parts and the control lines (`if (...) {`, `}`).
fn html(out: *Out, s: []const u8) !void {
    var i: usize = 0;
    var plain_from: usize = 0;
    var line_start = true;
    while (i < s.len) {
        const ch = s[i];
        var class: ?[]const u8 = null;
        var end = i + 1;
        if (std.mem.startsWith(u8, s[i..], "<!--")) {
            class = "c";
            end = if (std.mem.indexOfPos(u8, s, i, "-->")) |e| e + 3 else s.len;
        } else if (std.mem.startsWith(u8, s[i..], "-- ") and line_start) {
            class = "c";
            end = lineEnd(s, i);
        } else if (ch == '<' and i + 1 < s.len and (isIdentStart(s[i + 1]) or s[i + 1] == '/' or s[i + 1] == '!')) {
            // The tag name, then its attributes up to `>`.
            var j = i + 1;
            if (s[j] == '/' or s[j] == '!') j += 1;
            while (j < s.len and (isIdent(s[j]) or s[j] == '-' or s[j] == '.')) j += 1;
            try out.plain(s[plain_from..i]);
            try out.tok("tag", s[i..j]);
            while (j < s.len and s[j] != '>') {
                if (s[j] == '"' or s[j] == '\'') {
                    const e = stringEnd(s, j, s[j]);
                    try out.tok("s", s[j..e]);
                    j = e;
                } else if (s[j] == '{') {
                    const e = (std.mem.indexOfScalarPos(u8, s, j, '}') orelse s.len - 1) + 1;
                    try out.tok("p", s[j..e]);
                    j = e;
                } else if (isIdentStart(s[j]) or s[j] == '@' or s[j] == ':') {
                    var e = j;
                    while (e < s.len and (isIdent(s[e]) or s[e] == '-' or s[e] == ':' or s[e] == '@' or s[e] == '.')) e += 1;
                    try out.tok("a", s[j..e]);
                    j = e;
                } else {
                    try out.plain(s[j .. j + 1]);
                    j += 1;
                }
            }
            if (j < s.len) {
                if (j > 0 and s[j - 1] == '/') {} // `/>` was written as plain above
                try out.tok("tag", ">");
                j += 1;
            }
            plain_from = j;
            i = j;
            line_start = false;
            continue;
        } else if (ch == '{') {
            class = "p";
            var depth: usize = 0;
            var j = i;
            while (j < s.len) : (j += 1) {
                if (s[j] == '{') depth += 1;
                if (s[j] == '}') {
                    depth -= 1;
                    if (depth == 0) break;
                }
                if (s[j] == '\n') break;
            }
            end = if (j < s.len and s[j] == '}') j + 1 else i + 1;
        } else if (line_start and isIdentStart(ch)) {
            const e = identEnd(s, i);
            if (isOneOf(s[i..e], &template_keywords)) {
                class = "k";
                end = e;
            }
        } else if (line_start and ch == '}') {
            class = "k";
        }
        if (ch == '\n') {
            line_start = true;
        } else if (ch != ' ' and ch != '\t' and class == null) {
            line_start = false;
        }
        if (class) |cls| {
            try out.plain(s[plain_from..i]);
            try out.tok(cls, s[i..end]);
            plain_from = end;
            if (!std.mem.eql(u8, cls, "k") or ch != '}') line_start = false;
        }
        i = end;
    }
    try out.plain(s[plain_from..]);
}

fn json(out: *Out, s: []const u8) !void {
    var i: usize = 0;
    var plain_from: usize = 0;
    while (i < s.len) {
        const ch = s[i];
        var class: ?[]const u8 = null;
        var end = i + 1;
        if (ch == '"') {
            end = stringEnd(s, i, '"');
            class = if (nextNonSpace(s, end) == ':') "a" else "s";
        } else if (std.ascii.isDigit(ch) or (ch == '-' and i + 1 < s.len and std.ascii.isDigit(s[i + 1]))) {
            class = "n";
            end = numberEnd(s, i + 1);
        } else if (isIdentStart(ch)) {
            end = identEnd(s, i);
            if (isOneOf(s[i..end], &.{ "true", "false", "null" })) class = "k";
        }
        if (class) |cls| {
            try out.plain(s[plain_from..i]);
            try out.tok(cls, s[i..end]);
            plain_from = end;
        }
        i = end;
    }
    try out.plain(s[plain_from..]);
}

fn yaml(out: *Out, s: []const u8) !void {
    var lines = std.mem.splitScalar(u8, s, '\n');
    var first = true;
    while (lines.next()) |line| {
        if (!first) try out.plain("\n");
        first = false;
        const trimmed = std.mem.trimStart(u8, line, " -");
        const indent = line.len - trimmed.len;
        if (std.mem.startsWith(u8, trimmed, "#")) {
            try out.plain(line[0..indent]);
            try out.tok("c", trimmed);
        } else if (std.mem.indexOfScalar(u8, trimmed, ':')) |colon| {
            try out.plain(line[0..indent]);
            try out.tok("a", trimmed[0..colon]);
            try out.plain(":");
            const rest = trimmed[colon + 1 ..];
            const value = std.mem.trimStart(u8, rest, " ");
            try out.plain(rest[0 .. rest.len - value.len]);
            try out.tok("s", value);
        } else {
            try out.plain(line);
        }
    }
}

fn css(out: *Out, s: []const u8) !void {
    var i: usize = 0;
    var plain_from: usize = 0;
    var in_block = false;
    while (i < s.len) {
        const ch = s[i];
        var class: ?[]const u8 = null;
        var end = i + 1;
        if (ch == '/' and i + 1 < s.len and s[i + 1] == '*') {
            class = "c";
            end = if (std.mem.indexOfPos(u8, s, i + 2, "*/")) |e| e + 2 else s.len;
        } else if (ch == '{') {
            in_block = true;
        } else if (ch == '}') {
            in_block = false;
        } else if (ch == '"' or ch == '\'') {
            class = "s";
            end = stringEnd(s, i, ch);
        } else if (in_block and (isIdentStart(ch) or ch == '-') and (i == 0 or !isIdent(s[i - 1]))) {
            end = i;
            while (end < s.len and (isIdent(s[end]) or s[end] == '-')) end += 1;
            if (nextNonSpace(s, end) == ':') class = "a";
        } else if (!in_block and (ch == '.' or ch == '#' or isIdentStart(ch))) {
            end = i;
            while (end < s.len and s[end] != '{' and s[end] != ',' and s[end] != '\n') end += 1;
            while (end > i + 1 and s[end - 1] == ' ') end -= 1;
            class = "tag";
        }
        if (class) |cls| {
            try out.plain(s[plain_from..i]);
            try out.tok(cls, s[i..end]);
            plain_from = end;
        }
        i = end;
    }
    try out.plain(s[plain_from..]);
}

/// The text of a block back out of its highlighted HTML: the spans taken
/// away and the escapes undone. A block must read the same with colours.
fn textOf(arena: std.mem.Allocator, highlighted: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < highlighted.len) {
        if (highlighted[i] == '<') {
            i = (std.mem.indexOfScalarPos(u8, highlighted, i, '>') orelse highlighted.len - 1) + 1;
            continue;
        }
        try out.append(arena, highlighted[i]);
        i += 1;
    }
    return unescape(arena, out.items);
}

fn escapeForTest(arena: std.mem.Allocator, s: []const u8) ![]const u8 {
    var out: Out = .{ .arena = arena };
    try out.plain(s);
    return out.buf.items;
}

test "zig: keywords, strings, comments, builtins, types and calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const src = "/// The feed.\npub fn index(c: *spider.Ctx) !Response {\n    const q = @as(u8, 3) orelse \"x\";\n    return c.viewChecked(\"posts/index\", .{});\n}\n";
    const html_out = try highlight(a, .zig, try escapeForTest(a, src));
    try std.testing.expect(std.mem.indexOf(u8, html_out, "<span class=\"tok-c\">/// The feed.</span>") != null);
    try std.testing.expect(std.mem.indexOf(u8, html_out, "<span class=\"tok-k\">pub</span> <span class=\"tok-k\">fn</span> <span class=\"tok-f\">index</span>") != null);
    try std.testing.expect(std.mem.indexOf(u8, html_out, "<span class=\"tok-b\">@as</span>(<span class=\"tok-t\">u8</span>, <span class=\"tok-n\">3</span>)") != null);
    try std.testing.expect(std.mem.indexOf(u8, html_out, "<span class=\"tok-s\">&quot;posts/index&quot;</span>") != null);
    try std.testing.expect(std.mem.indexOf(u8, html_out, "<span class=\"tok-t\">Response</span>") != null);
    try std.testing.expectEqualStrings(src, try textOf(a, html_out));
}

test "every language keeps the text as it was, escaped" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cases = .{
        .{ Lang.bash, "curl -fsSL https://spiderme.org/install.sh | bash -s -- --version canary\n# a comment\nPORT=8080 ./app \"$HOME\" 'x'\n" },
        .{ Lang.sql, "CREATE TABLE posts (id INTEGER PRIMARY KEY, title TEXT NOT NULL DEFAULT 'a<b'); -- note\nSELECT * FROM posts WHERE id = $1;\n" },
        .{ Lang.html, "extends \"layout\"\n<!-- note -->\n<a class=\"ui-link { \"on\" if (x) }\" href=\"/posts\">{ post.title }</a>\nif (posts.len == 0) {\n<PostCard post={ p } />\n}\n-- props: amount!, on_sale: bool = false\n" },
        .{ Lang.json, "{ \"count\": 2, \"ok\": true, \"name\": \"a & b\", \"n\": -1.5 }\n" },
        .{ Lang.yaml, "services:\n  db:\n    image: postgres:17 # x\n  - name: web\n" },
        .{ Lang.css, "/* x */\n.ui-btn, a:hover { color: var(--ink); content: \"<\"; }\n" },
        .{ Lang.zig, "const s = \\\\multi\n    \\\\line\n;\nconst c = '\\'';\nconst e = error.NotFound;\n" },
    };
    inline for (cases) |case| {
        const escaped = try escapeForTest(a, case[1]);
        const out = try highlight(a, case[0], escaped);
        try std.testing.expectEqualStrings(case[1], try textOf(a, out));
        // Nothing of the code is left unescaped.
        try std.testing.expect(std.mem.indexOf(u8, out, "<b") == null);
    }
}

test "an unknown language is left as it is" {
    try std.testing.expectEqual(Lang.text, langOf("brainfuck"));
    try std.testing.expectEqual(Lang.bash, langOf("sh"));
    try std.testing.expectEqualStrings("a &lt; b", try highlight(std.testing.allocator, .text, "a &lt; b"));
}
