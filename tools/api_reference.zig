//! The API reference, generated from Spider's source.
//!
//! Starts at `src/spider.zig`, the file an app imports, and follows every
//! name it exports to where it is declared. What it finds there becomes
//! pages: the head of each declaration as written, its `///` comment, the
//! fields and the members of a type. tools/docs_index.zig adds those pages
//! to the ones written by hand, so they share the sidebar, the look and the
//! search.
//!
//! What is shown is what Spider marks as its API (see `AGENTS.md` there):
//! a `pub` name with a `///` comment. A name with a `// internal:` note, a
//! file whose header starts with `Internal:`, and a field or name that
//! starts with `_` are left out.
//!
//! A name `src/spider.zig` exports that cannot be followed stops the build
//! and says which: the reference never loses a part of the API quietly.

const std = @import("std");
const src = @import("api_source.zig");

/// Where the packages `src/spider.zig` imports by name live in the tree.
const modules = [_][2][]const u8{
    .{ "spider_pg", "modules/pg/src/pg.zig" },
    .{ "spider_sqlite", "modules/sqlite/src/sqlite.zig" },
    .{ "spider_r2", "modules/r2/src/r2.zig" },
    .{ "spider_qrcode", "modules/qrcode/src/root.zig" },
    .{ "spider_xlsx", "modules/xlsx/src/root.zig" },
    .{ "pacman", "modules/pacman/src/root.zig" },
};

pub const entry_file = "src/spider.zig";

/// Which page a source file's API goes to. A file not listed gets a page of
/// its own, named after what `src/spider.zig` calls it: a new part of the
/// API shows up without anyone editing this table.
const Placement = struct { prefix: []const u8, slug: []const u8, title: []const u8 };
const placements = [_]Placement{
    .{ .prefix = "src/core/context.zig", .slug = "api-ctx", .title = "Ctx and Response" },
    .{ .prefix = "src/core/download.zig", .slug = "api-ctx", .title = "Ctx and Response" },
    .{ .prefix = "src/core/app.zig", .slug = "api-server", .title = "Server" },
    .{ .prefix = "src/modules/static.zig", .slug = "api-server", .title = "Server" },
    .{ .prefix = "src/modules/health.zig", .slug = "api-server", .title = "Server" },
    .{ .prefix = "src/routing/", .slug = "api-group", .title = "Group and routes" },
    .{ .prefix = "src/core/extractors.zig", .slug = "api-extractors", .title = "Path, Form, Loaded" },
    .{ .prefix = "src/internal/config.zig", .slug = "api-config", .title = "Config" },
    .{ .prefix = "src/internal/env.zig", .slug = "api-env", .title = "env" },
    .{ .prefix = "src/render/", .slug = "api-templates", .title = "Template and RawHtml" },
    .{ .prefix = "src/binding/", .slug = "api-forms", .title = "Forms and uploads" },
    .{ .prefix = "src/modules/rbac.zig", .slug = "api-policies", .title = "Policies and roles" },
    .{ .prefix = "src/modules/session.zig", .slug = "api-session", .title = "session" },
    .{ .prefix = "src/modules/password.zig", .slug = "api-password", .title = "password" },
    .{ .prefix = "src/modules/auth/", .slug = "api-auth", .title = "auth (HS256 tokens)" },
    .{ .prefix = "modules/pg/", .slug = "api-pg", .title = "pg (PostgreSQL)" },
    .{ .prefix = "modules/sqlite/", .slug = "api-sqlite", .title = "sqlite" },
    .{ .prefix = "src/ws/", .slug = "api-realtime", .title = "Hub, Sse, Ws" },
    .{ .prefix = "modules/pacman/", .slug = "api-http-client", .title = "http_client" },
    .{ .prefix = "src/core/http_client_mtls.zig", .slug = "api-http-client", .title = "http_client" },
    .{ .prefix = "src/modules/mail/", .slug = "api-mail", .title = "mail" },
    .{ .prefix = "src/modules/push.zig", .slug = "api-push", .title = "push (Web Push)" },
    .{ .prefix = "src/middlewares/", .slug = "api-middlewares", .title = "Middlewares" },
    .{ .prefix = "src/modules/logger.zig", .slug = "api-middlewares", .title = "Middlewares" },
    .{ .prefix = "src/modules/errors.zig", .slug = "api-middlewares", .title = "Middlewares" },
    .{ .prefix = "src/modules/auth_marker.zig", .slug = "api-middlewares", .title = "Middlewares" },
    .{ .prefix = "src/internal/logfmt.zig", .slug = "api-middlewares", .title = "Middlewares" },
    .{ .prefix = "src/testing", .slug = "api-testing", .title = "testing" },
    .{ .prefix = "src/conventions.zig", .slug = "api-testing", .title = "testing" },
    .{ .prefix = "src/render/zmd/", .slug = "api-zmd", .title = "zmd (Markdown)" },
    .{ .prefix = "src/providers/keycloak.zig", .slug = "api-keycloak", .title = "keycloak" },
    .{ .prefix = "src/providers/jwks.zig", .slug = "api-jwks", .title = "jwks" },
    .{ .prefix = "src/providers/google.zig", .slug = "api-google", .title = "google" },
    .{ .prefix = "src/providers/clerk.zig", .slug = "api-clerk", .title = "clerk" },
    .{ .prefix = "modules/r2/", .slug = "api-r2", .title = "r2 (object storage)" },
    .{ .prefix = "modules/qrcode/", .slug = "api-qrcode", .title = "qrcode" },
    .{ .prefix = "modules/xlsx/", .slug = "api-xlsx", .title = "xlsx" },
};

/// Types the API hands out or takes that no name of `src/spider.zig`
/// reaches: shown on the page of the file they belong with.
const Extra = struct { path: []const u8, name: []const u8, slug: []const u8 };
const extras = [_]Extra{
    .{ .path = "src/routing/router.zig", .name = "RouteMeta", .slug = "api-group" },
};

pub const index_slug = "api";
pub const index_title = "API reference";

pub const Page = struct {
    slug: []const u8,
    title: []const u8,
    markdown: []const u8,
    /// The source file most of the page comes from, from Spider's root.
    source: []const u8,
    /// Every name the page documents, separated by spaces, for the search.
    keywords: []const u8,
};

pub const Error = error{
    /// `src/spider.zig` exports a name whose declaration was not found.
    ApiNameNotFound,
    /// A file the source refers to cannot be read.
    ApiFileNotFound,
} || std.mem.Allocator.Error;

/// Gives the text of a source file by its path from Spider's root, or null.
pub const ReadFn = *const fn (ctx: *anyopaque, arena: std.mem.Allocator, path: []const u8) ?[]const u8;

/// Every page of the reference: the list of everything first, then one page
/// per part of the API. `problem` says what is at fault when it fails.
pub fn generate(arena: std.mem.Allocator, ctx: *anyopaque, read: ReadFn, problem: *[]const u8) Error![]Page {
    var tree: Tree = .{ .arena = arena, .ctx = ctx, .read = read };
    problem.* = entry_file;
    const entry = try tree.file(entry_file);

    var builders: std.ArrayList(Builder) = .empty;
    for (entry.decls) |decl| {
        if (!shown(decl)) continue;
        problem.* = try std.fmt.allocPrint(arena, "{s}: `{s}`", .{ entry_file, decl.name });
        const target = try tree.follow(entry_file, decl);
        const path = switch (target) {
            .namespace => |p| p,
            .decl => |d| d.path,
        };
        // A whole file that says it is internal stays out, exported or not.
        if (target == .namespace and (try tree.file(path)).internal) continue;
        const place = placementFor(arena, path, decl.name) catch return error.OutOfMemory;
        const builder = blk: {
            for (builders.items) |*b| {
                if (std.mem.eql(u8, b.slug, place.slug)) break :blk b;
            }
            try builders.append(arena, .{ .slug = place.slug, .title = place.title, .source = path });
            break :blk &builders.items[builders.items.len - 1];
        };
        try builder.entries.append(arena, .{ .name = decl.name, .summary = firstParagraph(decl.doc), .target = target });
    }

    // In the order of the table above; pages it does not name come last,
    // in the order `src/spider.zig` exports them.
    std.mem.sort(Builder, builders.items, {}, Builder.before);

    var pages: std.ArrayList(Page) = .empty;
    try pages.append(arena, try indexPage(arena, builders.items));
    for (builders.items) |*builder| {
        problem.* = builder.slug;
        try pages.append(arena, try builder.page(&tree));
    }
    return pages.items;
}

/// A name that goes to the reference: public, not marked internal, not a
/// name Spider keeps for itself.
fn shown(decl: src.Decl) bool {
    return decl.public and !decl.internal and !std.mem.startsWith(u8, decl.name, "_");
}

const Target = union(enum) {
    /// A whole file used as a namespace: `spider.pg`.
    namespace: []const u8,
    /// One declaration of a file.
    decl: struct { path: []const u8, decl: src.Decl },
};

const Entry = struct {
    /// The name in `src/spider.zig`.
    name: []const u8,
    /// The first paragraph of its comment there.
    summary: []const u8,
    target: Target,
};

/// The source tree, read and parsed on demand.
const Tree = struct {
    arena: std.mem.Allocator,
    ctx: *anyopaque,
    read: ReadFn,
    files: std.StringHashMapUnmanaged(src.File) = .empty,

    fn file(self: *Tree, path: []const u8) Error!src.File {
        if (self.files.get(path)) |known| return known;
        const text = self.read(self.ctx, self.arena, path) orelse return error.ApiFileNotFound;
        const parsed = try src.parse(self.arena, text);
        try self.files.put(self.arena, try self.arena.dupe(u8, path), parsed);
        return parsed;
    }

    /// Where a declaration of `path` really is: itself, or what its value
    /// names (`const X = @import("f.zig").Y;`, `const p = rbac.policy;`).
    fn follow(self: *Tree, path: []const u8, decl: src.Decl) Error!Target {
        if (decl.kind == .constant and decl.value.len > 0) {
            if (try self.resolve(path, decl.value, 0)) |target| return target;
        }
        return .{ .decl = .{ .path = path, .decl = decl } };
    }

    /// What an expression written in `path` names, when it is an import or
    /// a path of names: `@import("f.zig")`, `@import("f.zig").A.B`, `a.B`.
    /// Null for anything else (a number, a call, a type expression).
    fn resolve(self: *Tree, path: []const u8, expr: []const u8, depth: usize) Error!?Target {
        if (depth > 8) return null;
        var rest = expr;
        var current: Target = undefined;

        const import_open = "@import(\"";
        if (std.mem.startsWith(u8, rest, import_open)) {
            const close = std.mem.indexOfPos(u8, rest, import_open.len, "\")") orelse return null;
            const name = rest[import_open.len..close];
            rest = rest[close + 2 ..];
            const target_path = if (std.mem.endsWith(u8, name, ".zig"))
                try std.fs.path.resolvePosix(self.arena, &.{ std.fs.path.dirnamePosix(path) orelse "", name })
            else
                moduleFile(name) orelse return null;
            current = .{ .namespace = target_path };
        } else {
            const first = identifierAt(rest) orelse return null;
            const here = try self.file(path);
            const local = here.find(first) orelse return null;
            // `const X = X;` would loop.
            if (std.mem.eql(u8, local.value, expr)) return null;
            current = try self.followAt(path, local, depth + 1);
            rest = rest[first.len..];
        }

        while (rest.len > 0) {
            if (rest[0] != '.') return null;
            const name = identifierAt(rest[1..]) orelse return null;
            rest = rest[1 + name.len ..];
            switch (current) {
                .namespace => |ns| {
                    const in = try self.file(ns);
                    const found = in.find(name) orelse return error.ApiNameNotFound;
                    current = try self.followAt(ns, found, depth + 1);
                },
                .decl => |d| {
                    const found = for (d.decl.members) |member| {
                        if (std.mem.eql(u8, member.name, name)) break member;
                    } else return error.ApiNameNotFound;
                    current = try self.followAt(d.path, found, depth + 1);
                },
            }
        }
        return current;
    }

    fn followAt(self: *Tree, path: []const u8, decl: src.Decl, depth: usize) Error!Target {
        if (decl.kind == .constant and decl.value.len > 0) {
            if (try self.resolve(path, decl.value, depth)) |target| return target;
        }
        return .{ .decl = .{ .path = path, .decl = decl } };
    }
};

fn moduleFile(name: []const u8) ?[]const u8 {
    for (modules) |module| {
        if (std.mem.eql(u8, module[0], name)) return module[1];
    }
    return null;
}

fn identifierAt(text: []const u8) ?[]const u8 {
    if (text.len > 1 and text[0] == '@' and text[1] == '"') {
        const close = std.mem.indexOfScalarPos(u8, text, 2, '"') orelse return null;
        return text[0 .. close + 1];
    }
    var end: usize = 0;
    while (end < text.len and (std.ascii.isAlphanumeric(text[end]) or text[end] == '_')) end += 1;
    return if (end == 0) null else text[0..end];
}

fn placementFor(arena: std.mem.Allocator, path: []const u8, name: []const u8) !Placement {
    // The longest prefix wins: `src/render/zmd/` over `src/render/`.
    var best: ?Placement = null;
    for (placements) |place| {
        if (!std.mem.startsWith(u8, path, place.prefix)) continue;
        if (best == null or place.prefix.len > best.?.prefix.len) best = place;
    }
    if (best) |place| return place;
    var slug: std.ArrayList(u8) = .empty;
    try slug.appendSlice(arena, "api-");
    for (name) |ch| {
        if (std.ascii.isAlphanumeric(ch)) {
            try slug.append(arena, std.ascii.toLower(ch));
        } else if (slug.items[slug.items.len - 1] != '-') {
            try slug.append(arena, '-');
        }
    }
    return .{ .prefix = path, .slug = slug.items, .title = name };
}

/// One page being put together.
const Builder = struct {
    slug: []const u8,
    title: []const u8,
    source: []const u8,
    entries: std.ArrayList(Entry) = .empty,

    fn rank(self: Builder) usize {
        for (placements, 0..) |place, i| {
            if (std.mem.eql(u8, place.slug, self.slug)) return i;
        }
        return placements.len;
    }

    fn before(_: void, a: Builder, b: Builder) bool {
        return a.rank() < b.rank();
    }

    fn page(self: *Builder, tree: *Tree) Error!Page {
        const arena = tree.arena;
        var out: std.ArrayList(u8) = .empty;
        var names: std.ArrayList(u8) = .empty;
        try out.print(arena, "# {s}\n\n", .{self.title});

        // What the page holds, by the name an app writes.
        try out.appendSlice(arena, "On this page:\n\n");
        for (self.entries.items) |entry| {
            try out.print(arena, "- [spider.{s}](#{s})", .{ entry.name, try headingId(arena, try std.fmt.allocPrint(arena, "spider.{s}", .{entry.name})) });
            if (entry.summary.len > 0) try out.print(arena, ": {s}", .{try oneLine(arena, entry.summary)});
            try out.append(arena, '\n');
        }
        try out.append(arena, '\n');

        // A namespace and a shortcut to one of its names (`spider.rbac` and
        // `spider.policy`) show the declaration once, under the namespace.
        for (self.entries.items) |entry| {
            const qualified = try std.fmt.allocPrint(arena, "spider.{s}", .{entry.name});
            try names.print(arena, "{s} {s} ", .{ entry.name, qualified });
            switch (entry.target) {
                .namespace => |path| {
                    const file = try tree.file(path);
                    try out.print(arena, "## `{s}`\n\n", .{qualified});
                    if (file.header.len > 0) try out.print(arena, "{s}\n\n", .{try docMarkdown(arena, file.header)});
                    if (file.fields.len > 0) try renderFields(arena, &out, file.fields, "Fields");
                    for (file.decls) |decl| {
                        if (!shown(decl)) continue;
                        // Inside a file, a value that cannot be followed is
                        // just a constant: only the entry file is strict.
                        const target = tree.follow(path, decl) catch |err| switch (err) {
                            error.OutOfMemory => return err,
                            else => Target{ .decl = .{ .path = path, .decl = decl } },
                        };
                        switch (target) {
                            .namespace => |inner_path| {
                                // A file is a struct. Reexported with a
                                // comment, it is a type of the API; without
                                // one, it is there for the module's own use.
                                const inner = try tree.file(inner_path);
                                if (decl.doc.len == 0 or inner.internal) continue;
                                try renderDecl(arena, &out, &names, qualified, .{
                                    .name = decl.name,
                                    .kind = .container,
                                    .public = true,
                                    .internal = false,
                                    // With fields it is a type; without,
                                    // a namespace inside the namespace.
                                    .signature = if (inner.fields.len > 0)
                                        try std.fmt.allocPrint(arena, "pub const {s} = struct", .{decl.name})
                                    else
                                        "",
                                    .doc = decl.doc,
                                    .value = "",
                                    .fields = inner.fields,
                                    .members = inner.decls,
                                    .line = decl.line,
                                }, 3);
                            },
                            .decl => |d| {
                                // An alias of an internal name is not API either.
                                if (d.decl.internal or (decl.doc.len == 0 and d.decl.doc.len == 0)) continue;
                                const file_of_target = try tree.file(d.path);
                                if (file_of_target.internal and decl.doc.len == 0) continue;
                                var real = d.decl;
                                real.name = decl.name;
                                if (real.doc.len == 0) real.doc = decl.doc;
                                try renderDecl(arena, &out, &names, qualified, real, 3);
                            },
                        }
                    }
                },
                .decl => |d| {
                    if (self.coveredByNamespace(d.path, d.decl)) {
                        try out.print(arena, "## `{s}`\n\n", .{qualified});
                        const ns = self.namespaceOf(d.path).?;
                        try out.print(arena, "The same as [spider.{s}.{s}](#{s}).\n\n", .{
                            ns,
                            d.decl.name,
                            try headingId(arena, try std.fmt.allocPrint(arena, "spider.{s}.{s}", .{ ns, d.decl.name })),
                        });
                        continue;
                    }
                    var real = d.decl;
                    real.name = entry.name;
                    try renderDecl(arena, &out, &names, "spider", real, 2);
                },
            }
        }
        try self.related(tree, &out, &names);
        return .{
            .slug = self.slug,
            .title = self.title,
            .markdown = out.items,
            .source = self.source,
            .keywords = std.mem.trim(u8, names.items, " "),
        };
    }

    /// The documented declarations that sit beside the ones shown above
    /// without a name of their own in `src/spider.zig`: the options a
    /// method takes, the type another returns (`ResponseOptions`,
    /// `CookieOptions`). An app meets them through the names above.
    fn related(self: *Builder, tree: *Tree, out: *std.ArrayList(u8), names: *std.ArrayList(u8)) Error!void {
        const arena = tree.arena;
        var files: std.ArrayList([]const u8) = .empty;
        var taken: std.ArrayList(Taken) = .empty;
        for (self.entries.items) |entry| {
            switch (entry.target) {
                // A namespace lists everything its file documents already.
                .namespace => |path| try taken.append(arena, .{ .path = path, .line = 0 }),
                .decl => |d| {
                    try taken.append(arena, .{ .path = d.path, .line = d.decl.line });
                    if (std.mem.eql(u8, d.path, entry_file)) continue;
                    const known = for (files.items) |f| {
                        if (std.mem.eql(u8, f, d.path)) break true;
                    } else false;
                    if (!known) try files.append(arena, d.path);
                },
            }
        }

        var found: std.ArrayList(src.Decl) = .empty;
        for (files.items) |path| {
            const file = try tree.file(path);
            if (file.internal) continue;
            decls: for (file.decls) |decl| {
                if (!shown(decl) or decl.doc.len == 0) continue;
                for (taken.items) |known| {
                    if (std.mem.eql(u8, known.path, path) and (known.line == 0 or known.line == decl.line)) continue :decls;
                }
                // An alias of something shown elsewhere is not a new name.
                if (decl.kind == .constant and decl.value.len > 0 and std.mem.startsWith(u8, decl.value, "@import(")) continue;
                try found.append(arena, decl);
            }
        }
        for (extras) |extra| {
            if (!std.mem.eql(u8, extra.slug, self.slug)) continue;
            const file = try tree.file(extra.path);
            try found.append(arena, file.find(extra.name) orelse return error.ApiNameNotFound);
        }
        if (found.items.len == 0) return;

        try out.appendSlice(arena, "## Related\n\nWhat the declarations above take or give back, without a name of its own in `spider`.\n\n");
        for (found.items) |decl| try renderDecl(arena, out, names, "", decl, 3);
    }

    const Taken = struct { path: []const u8, line: usize };

    /// The name of the namespace entry of this page whose file is `path`.
    fn namespaceOf(self: *Builder, path: []const u8) ?[]const u8 {
        for (self.entries.items) |entry| {
            switch (entry.target) {
                .namespace => |ns| if (std.mem.eql(u8, ns, path)) return entry.name,
                .decl => {},
            }
        }
        return null;
    }

    fn coveredByNamespace(self: *Builder, path: []const u8, decl: src.Decl) bool {
        return self.namespaceOf(path) != null and decl.doc.len > 0;
    }
};

/// One declaration: a heading with its full name, its head as code, its
/// comment, then its fields and its documented members.
fn renderDecl(arena: std.mem.Allocator, out: *std.ArrayList(u8), names: *std.ArrayList(u8), parent: []const u8, decl: src.Decl, level: usize) Error!void {
    const qualified = if (parent.len == 0) decl.name else try std.fmt.allocPrint(arena, "{s}.{s}", .{ parent, decl.name });
    try names.print(arena, "{s} ", .{decl.name});
    const marks: [4]u8 = @splat('#');
    // As code: the site's Markdown would read `a_b_c` as "a", italic "b", "c".
    try out.print(arena, "{s} `{s}`\n\n", .{ marks[0..@min(level, 4)], qualified });
    if (decl.signature.len > 0) try out.print(arena, "```zig\n{s}\n```\n\n", .{decl.signature});
    if (decl.doc.len > 0) try out.print(arena, "{s}\n\n", .{try docMarkdown(arena, decl.doc)});

    if (decl.fields.len > 0) try renderFields(arena, out, decl.fields, listLabel(decl.signature));

    // Members are named from the type, not from `spider.`: `Ctx.json`.
    const short = if (std.mem.startsWith(u8, qualified, "spider.")) qualified["spider.".len..] else qualified;
    for (decl.members) |member| {
        if (!shown(member) or member.doc.len == 0) continue;
        try renderDecl(arena, out, names, short, member, level + 1);
    }
}

/// What the list of a type's fields is called: an enum has values, an error
/// set has errors.
fn listLabel(signature: []const u8) []const u8 {
    if (std.mem.endsWith(u8, signature, "= error")) return "Errors";
    if (std.mem.indexOf(u8, signature, "= enum") != null) return "Values";
    return "Fields";
}

fn renderFields(arena: std.mem.Allocator, out: *std.ArrayList(u8), fields: []const src.Field, label: []const u8) Error!void {
    var any = false;
    for (fields) |field| {
        if (std.mem.startsWith(u8, field.name, "_")) continue;
        if (!any) try out.print(arena, "**{s}**\n\n", .{label});
        any = true;
        try out.print(arena, "- `{s}{s}{s}`", .{ field.name, if (field.rest.len > 0 and field.rest[0] == '=') " " else "", field.rest });
        if (field.doc.len > 0) try out.print(arena, ": {s}", .{try oneLine(arena, field.doc)});
        try out.append(arena, '\n');
    }
    if (any) try out.append(arena, '\n');
}

fn indexPage(arena: std.mem.Allocator, builders: []const Builder) Error!Page {
    var out: std.ArrayList(u8) = .empty;
    var names: std.ArrayList(u8) = .empty;
    try out.print(arena, "# {s}\n\n", .{index_title});
    try out.appendSlice(arena,
        \\Everything an app reaches through `const spider = @import("spider");`, by the name it writes.
        \\
        \\These pages are generated from the comments in Spider's source code each time the site is built, so they describe the code as it is. A name that is public only for Spider's own files is not listed.
        \\
        \\
    );
    for (builders) |builder| {
        try out.print(arena, "## [{s}](/docs/{s})\n\n", .{ builder.title, builder.slug });
        for (builder.entries.items) |entry| {
            try names.print(arena, "{s} ", .{entry.name});
            try out.print(arena, "- [spider.{s}](/docs/{s}#{s})", .{
                entry.name,
                builder.slug,
                try headingId(arena, try std.fmt.allocPrint(arena, "spider.{s}", .{entry.name})),
            });
            if (entry.summary.len > 0) try out.print(arena, ": {s}", .{try oneLine(arena, entry.summary)});
            try out.append(arena, '\n');
        }
        try out.append(arena, '\n');
    }
    return .{
        .slug = index_slug,
        .title = index_title,
        .markdown = out.items,
        .source = entry_file,
        .keywords = std.mem.trim(u8, names.items, " "),
    };
}

/// The id a heading gets on the page (the site's controller makes the same
/// one): anything but letters and digits a single `-`. The case is kept:
/// `pg.Transaction` and `pg.transaction` are two names.
pub fn headingId(arena: std.mem.Allocator, text: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    for (text) |ch| {
        if (std.ascii.isAlphanumeric(ch)) {
            try out.append(arena, ch);
        } else if (out.items.len > 0 and out.items[out.items.len - 1] != '-') {
            try out.append(arena, '-');
        }
    }
    return std.mem.trimEnd(u8, out.items, "-");
}

fn firstParagraph(doc: []const u8) []const u8 {
    const end = std.mem.indexOf(u8, doc, "\n\n") orelse doc.len;
    return std.mem.trim(u8, doc[0..end], " \n");
}

/// A comment as one line of a list: its first paragraph, line breaks as
/// spaces. A paragraph that opens a code block is cut before it.
fn oneLine(arena: std.mem.Allocator, doc: []const u8) ![]const u8 {
    var first = firstParagraph(doc);
    if (std.mem.indexOf(u8, first, "```")) |fence| first = std.mem.trim(u8, first[0..fence], " \n");
    const out = try arena.dupe(u8, first);
    for (out) |*ch| {
        if (ch.* == '\n') ch.* = ' ';
    }
    return protectNames(arena, out);
}

/// One line of prose with every bare name that has a `_` put in backticks:
/// the site's Markdown reads `_` as the mark of italics, so two names such
/// as `org_roles` and `quiet_log` on one line would lose an underscore each. What
/// already is inside backticks, and a link's address, are left alone.
fn protectNames(arena: std.mem.Allocator, line: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    var in_code = false;
    while (i < line.len) {
        const ch = line[i];
        if (ch == '`') {
            in_code = !in_code;
            try out.append(arena, ch);
            i += 1;
            continue;
        }
        // A link, `[text](address)`, is copied as it is: its text is not
        // read for italics, and code inside it would break the link.
        if (!in_code and ch == '[') {
            if (std.mem.indexOfPos(u8, line, i, "](")) |middle| {
                if (std.mem.indexOfScalarPos(u8, line, middle, ')')) |close| {
                    try out.appendSlice(arena, line[i .. close + 1]);
                    i = close + 1;
                    continue;
                }
            }
        }
        const starts_word = std.ascii.isAlphanumeric(ch) or ch == '_';
        if (in_code or !starts_word) {
            try out.append(arena, ch);
            i += 1;
            continue;
        }
        var end = i;
        var underscores: usize = 0;
        while (end < line.len and (std.ascii.isAlphanumeric(line[end]) or line[end] == '_')) : (end += 1) {
            if (line[end] == '_') underscores += 1;
        }
        const word = line[i..end];
        if (underscores >= 1) {
            try out.print(arena, "`{s}`", .{word});
        } else {
            try out.appendSlice(arena, word);
        }
        i = end;
    }
    return out.items;
}

/// A doc comment as the Markdown of a page. Two things differ from how
/// comments are written: a paragraph or a list item wrapped over several
/// lines becomes one line (the site's Markdown starts a paragraph at every
/// line break), and an example written as an indented block (four spaces
/// after a blank line) becomes a fenced one.
pub fn docMarkdown(arena: std.mem.Allocator, doc: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var block: std.ArrayList(u8) = .empty; // the paragraph or list item being joined
    var lines = std.mem.splitScalar(u8, doc, '\n');
    var in_fence = false; // a ``` block of the comment itself
    var in_indented = false; // an indented block being turned into one
    var previous_blank = true;
    var in_list = false;
    while (lines.next()) |line| {
        const text = std.mem.trimStart(u8, line, " ");
        if (std.mem.startsWith(u8, text, "```")) {
            try flush(arena, &out, &block);
            if (in_indented) {
                try out.appendSlice(arena, "```\n");
                in_indented = false;
            }
            in_fence = !in_fence;
            try out.print(arena, "{s}\n", .{text});
            previous_blank = false;
            continue;
        }
        if (in_fence) {
            try out.print(arena, "{s}\n", .{line});
            continue;
        }
        const indented = line.len - text.len >= 4 and text.len > 0;
        if (in_indented) {
            if (indented) {
                try out.print(arena, "{s}\n", .{line[4..]});
                continue;
            }
            if (text.len == 0) {
                // A blank line inside the example, or its end: look ahead.
                const next = std.mem.trimStart(u8, lines.rest(), "\n");
                if (std.mem.startsWith(u8, next, "    ")) {
                    try out.append(arena, '\n');
                    continue;
                }
            }
            try out.appendSlice(arena, "```\n");
            in_indented = false;
        }
        if (indented and previous_blank and !in_list) {
            try flush(arena, &out, &block);
            try out.appendSlice(arena, "```zig\n");
            try out.print(arena, "{s}\n", .{line[4..]});
            in_indented = true;
            continue;
        }
        if (text.len == 0) {
            try flush(arena, &out, &block);
            try out.append(arena, '\n');
            previous_blank = true;
            // A list goes on after a blank line only if an item follows.
            in_list = in_list and listItem(std.mem.trimStart(u8, lines.rest(), " \n"));
            continue;
        }
        previous_blank = false;
        if (listItem(text)) {
            try flush(arena, &out, &block);
            in_list = true;
            // Keep the indentation: it is what nests one list in another.
            try block.appendSlice(arena, line);
            continue;
        }
        if (text[0] == '#') {
            try flush(arena, &out, &block);
            try out.print(arena, "{s}\n", .{text});
            continue;
        }
        if (block.items.len > 0) try block.append(arena, ' ');
        try block.appendSlice(arena, text);
    }
    try flush(arena, &out, &block);
    if (in_indented) try out.appendSlice(arena, "```\n");
    return std.mem.trim(u8, out.items, "\n");
}

/// Writes the joined paragraph or list item, its bare names protected.
fn flush(arena: std.mem.Allocator, out: *std.ArrayList(u8), block: *std.ArrayList(u8)) !void {
    if (block.items.len == 0) return;
    try out.print(arena, "{s}\n", .{try protectNames(arena, block.items)});
    block.clearRetainingCapacity();
}

/// `- x`, `* x`, `1. x` or `1) x`.
fn listItem(text: []const u8) bool {
    if (std.mem.startsWith(u8, text, "- ") or std.mem.startsWith(u8, text, "* ")) return true;
    var digits: usize = 0;
    while (digits < text.len and std.ascii.isDigit(text[digits])) digits += 1;
    return digits > 0 and digits + 1 < text.len and (text[digits] == '.' or text[digits] == ')') and text[digits + 1] == ' ';
}

// ── tests ───────────────────────────────────────────────────────────────

const t = std.testing;

/// A small tree of sources, by path.
const Fake = struct {
    files: []const [2][]const u8,

    fn read(ctx: *anyopaque, _: std.mem.Allocator, path: []const u8) ?[]const u8 {
        const self: *Fake = @ptrCast(@alignCast(ctx));
        for (self.files) |file| {
            if (std.mem.eql(u8, file[0], path)) return file[1];
        }
        return null;
    }
};

const fake_tree = [_][2][]const u8{
    .{ "src/spider.zig",
    \\//! The entry.
    \\const std = @import("std");
    \\/// The request.
    \\pub const Ctx = @import("core/context.zig").Ctx;
    \\/// PostgreSQL.
    \\pub const pg = @import("spider_pg");
    \\/// Access rules.
    \\pub const rbac = @import("modules/rbac.zig");
    \\/// A named rule.
    \\pub const policy = rbac.policy;
    \\// internal: plumbing.
    \\pub const ast = @import("render/ast.zig");
    \\/// A helper of its own.
    \\pub fn helper(n: usize) usize {
    \\    return n;
    \\}
    \\/// Something new, with no page chosen for it.
    \\pub const brand_new = @import("fresh/thing.zig");
    },
    .{ "src/core/context.zig",
    \\//! The request and the response.
    \\/// What every handler receives.
    \\///
    \\///     fn show(c: *spider.Ctx) !spider.Response {
    \\///         return c.text("hi", .{});
    \\///     }
    \\pub const Ctx = struct {
    \\    /// Memory for the request.
    \\    arena: std.mem.Allocator,
    \\    _io: std.Io = undefined,
    \\
    \\    /// A JSON response.
    \\    pub fn json(self: *Ctx, value: anytype) !Response {
    \\        _ = self;
    \\    }
    \\
    \\    // internal: the server sets it.
    \\    pub fn setLoaded(self: *Ctx) void {
    \\        _ = self;
    \\    }
    \\
    \\    /// Who a request is from.
    \\    pub const User = struct {
    \\        id: []const u8,
    \\    };
    \\};
    },
    .{ "modules/pg/src/pg.zig",
    \\//! PostgreSQL for an app.
    \\const driver = @import("driver.zig");
    \\/// Runs one statement.
    \\pub fn query(sql: []const u8) !void {
    \\    _ = sql;
    \\}
    \\// internal: for the tests.
    \\pub fn acquire() void {}
    \\/// A transaction.
    \\pub const Transaction = driver.Transaction;
    \\pub const raw = driver;
    },
    .{ "modules/pg/src/driver.zig",
    \\//! Internal: the wire protocol.
    \\/// One transaction on one connection.
    \\pub const Transaction = struct {
    \\    /// Commits.
    \\    pub fn commit(self: *Transaction) !void {
    \\        _ = self;
    \\    }
    \\};
    },
    .{ "src/modules/rbac.zig",
    \\//! Access rules.
    \\/// A rule with a name.
    \\pub fn policy(comptime name: []const u8) Policy {
    \\    _ = name;
    \\}
    },
    .{ "src/fresh/thing.zig",
    \\//! A new part.
    \\/// Does the new thing.
    \\pub fn go() void {}
    },
};

fn generated(arena: *std.heap.ArenaAllocator) ![]Page {
    var fake: Fake = .{ .files = &fake_tree };
    var problem: []const u8 = "";
    return generate(arena.allocator(), &fake, Fake.read, &problem);
}

fn pageNamed(pages: []const Page, slug: []const u8) ?Page {
    for (pages) |page| {
        if (std.mem.eql(u8, page.slug, slug)) return page;
    }
    return null;
}

test "generate: one page per part of the API, and the list of everything first" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const pages = try generated(&arena);

    try t.expectEqualStrings("api", pages[0].slug);
    try t.expect(pageNamed(pages, "api-ctx") != null);
    try t.expect(pageNamed(pages, "api-pg") != null);
    try t.expect(pageNamed(pages, "api-policies") != null);
    // A file no placement names still gets a page.
    try t.expect(pageNamed(pages, "api-brand-new") != null);
    // The entry file's own function has one too.
    try t.expect(pageNamed(pages, "api-helper") != null);

    const index = pages[0].markdown;
    try t.expect(std.mem.indexOf(u8, index, "- [spider.Ctx](/docs/api-ctx#spider-Ctx): The request.") != null);
    try t.expect(std.mem.indexOf(u8, index, "- [spider.pg](/docs/api-pg#spider-pg): PostgreSQL.") != null);
    // A name marked internal is nowhere.
    try t.expect(std.mem.indexOf(u8, index, "spider.ast") == null);
}

test "generate: a type shows its head, its comment, its fields and its documented members" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const page = pageNamed(try generated(&arena), "api-ctx").?;
    const md = page.markdown;

    try t.expect(std.mem.startsWith(u8, md, "# Ctx and Response\n"));
    try t.expect(std.mem.indexOf(u8, md, "## `spider.Ctx`\n\n```zig\npub const Ctx = struct\n```\n\nWhat every handler receives.") != null);
    // The indented example of the comment became a fenced block.
    try t.expect(std.mem.indexOf(u8, md, "```zig\nfn show(c: *spider.Ctx) !spider.Response {\n    return c.text(\"hi\", .{});\n}\n```") != null);
    try t.expect(std.mem.indexOf(u8, md, "- `arena: std.mem.Allocator`: Memory for the request.") != null);
    try t.expect(std.mem.indexOf(u8, md, "### `Ctx.json`\n\n```zig\npub fn json(self: *Ctx, value: anytype) !Response\n```\n\nA JSON response.") != null);
    try t.expect(std.mem.indexOf(u8, md, "### `Ctx.User`") != null);
    // Not shown: a field that starts with `_`, a member marked internal.
    try t.expect(std.mem.indexOf(u8, md, "_io") == null);
    try t.expect(std.mem.indexOf(u8, md, "setLoaded") == null);
    try t.expectEqualStrings("src/core/context.zig", page.source);
    try t.expect(std.mem.indexOf(u8, page.keywords, "json") != null);
}

test "generate: a namespace lists what its file documents, following aliases" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const md = pageNamed(try generated(&arena), "api-pg").?.markdown;

    try t.expect(std.mem.indexOf(u8, md, "## `spider.pg`\n\nPostgreSQL for an app.") != null);
    try t.expect(std.mem.indexOf(u8, md, "### `spider.pg.query`\n\n```zig\npub fn query(sql: []const u8) !void\n```\n\nRuns one statement.") != null);
    // An alias shows the real declaration, with its members.
    try t.expect(std.mem.indexOf(u8, md, "### `spider.pg.Transaction`\n\n```zig\npub const Transaction = struct\n```\n\nOne transaction on one connection.") != null);
    try t.expect(std.mem.indexOf(u8, md, "#### `pg.Transaction.commit`") != null);
    // Not shown: marked internal; a whole file reexported without a comment.
    try t.expect(std.mem.indexOf(u8, md, "acquire") == null);
    try t.expect(std.mem.indexOf(u8, md, "spider.pg.raw") == null);
}

test "generate: a shortcut to a name of a namespace points at it" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const md = pageNamed(try generated(&arena), "api-policies").?.markdown;

    try t.expect(std.mem.indexOf(u8, md, "### `spider.rbac.policy`") != null);
    try t.expect(std.mem.indexOf(u8, md, "## `spider.policy`\n\nThe same as [spider.rbac.policy](#spider-rbac-policy).") != null);
}

test "generate: a name that cannot be followed stops the build and says which" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const broken = [_][2][]const u8{
        .{ "src/spider.zig", "/// Gone.\npub const Lost = @import(\"core/context.zig\").Lost;\n" },
        .{ "src/core/context.zig", "pub const Ctx = struct {};\n" },
    };
    var fake: Fake = .{ .files = &broken };
    var problem: []const u8 = "";
    try t.expectError(error.ApiNameNotFound, generate(arena.allocator(), &fake, Fake.read, &problem));
    try t.expectEqualStrings("src/spider.zig: `Lost`", problem);

    const missing = [_][2][]const u8{.{ "src/spider.zig", "/// Gone.\npub const x = @import(\"nowhere.zig\");\npub const y = x.thing;\n" }};
    var fake2: Fake = .{ .files = &missing };
    try t.expectError(error.ApiFileNotFound, generate(arena.allocator(), &fake2, Fake.read, &problem));
}

test "headingId: what a heading is linked by" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    try t.expectEqualStrings("spider-Ctx", try headingId(arena.allocator(), "spider.Ctx"));
    try t.expectEqualStrings("Ctx-redirectWith", try headingId(arena.allocator(), "Ctx.redirectWith"));
    try t.expectEqualStrings("pg-Transaction-commit", try headingId(arena.allocator(), "pg.Transaction.commit"));
    try t.expectEqualStrings("auth-HS256-tokens", try headingId(arena.allocator(), "auth (HS256 tokens)"));
}

test "docMarkdown: an indented example becomes a fenced block; lists and fences stay" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    try t.expectEqualStrings(
        "Text:\n\n```zig\nconst x = 1;\n\nconst y = 2;\n```\n\nMore.",
        try docMarkdown(a, "Text:\n\n    const x = 1;\n\n    const y = 2;\n\nMore."),
    );
    // A list whose items continue on indented lines is not code; each item
    // becomes one line.
    try t.expectEqualStrings(
        "Does:\n\n- one thing that goes on\n- another\n  - nested one more line",
        try docMarkdown(a, "Does:\n\n- one thing\n    that goes on\n- another\n  - nested\n    one more line"),
    );
    // A paragraph written over several lines is one line.
    try t.expectEqualStrings(
        "First line and second line.\n\nNext paragraph, with `a_name` in it.",
        try docMarkdown(a, "First line\nand second line.\n\nNext paragraph,\nwith a_name in it."),
    );
    // Numbered steps.
    try t.expectEqualStrings("In order:\n\n1. first step\n2. second step, wrapped", try docMarkdown(a, "In order:\n\n1. first\n   step\n2. second step,\n   wrapped"));
    // A fenced block is left as written, indentation included.
    const fenced = "Use:\n\n```zig\nif (x) {\n    y();\n}\n```";
    try t.expectEqualStrings(fenced, try docMarkdown(a, fenced));
}

test "protectNames: a bare name with underscores keeps them" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try t.expectEqualStrings("Set `max_body_bytes` or `static_max_file_bytes`.", try protectNames(a, "Set max_body_bytes or `static_max_file_bytes`."));
    try t.expectEqualStrings("`one_under` too, [a_b_c text](/docs/x_y_z) not", try protectNames(a, "one_under too, [a_b_c text](/docs/x_y_z) not"));
    try t.expectEqualStrings("no underscore, nothing changes: a-b c.d", try protectNames(a, "no underscore, nothing changes: a-b c.d"));
    try t.expectEqualStrings("names like `_auth_sub` and `__session`", try protectNames(a, "names like _auth_sub and __session"));
}

test "generate: what a shown declaration uses, from the same file, comes after it" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const tree = [_][2][]const u8{
        .{ "src/spider.zig", "/// The request.\npub const Ctx = @import(\"core/context.zig\").Ctx;\n" },
        .{ "src/core/context.zig", 
        \\const std = @import("std");
        \\/// What a response may carry.
        \\pub const ResponseOptions = struct {
        \\    status: u16 = 200,
        \\};
        \\// internal: plumbing.
        \\pub const ViewsConfig = struct {};
        \\/// The request.
        \\pub const Ctx = struct {};
        },
    };
    var fake: Fake = .{ .files = &tree };
    var problem: []const u8 = "";
    const md = pageNamed(try generate(arena.allocator(), &fake, Fake.read, &problem), "api-ctx").?.markdown;
    const related = std.mem.indexOf(u8, md, "## Related").?;
    try t.expect(std.mem.indexOf(u8, md, "## `spider.Ctx`").? < related);
    try t.expect(std.mem.indexOfPos(u8, md, related, "### `ResponseOptions`\n\n```zig\npub const ResponseOptions = struct\n```") != null);
    try t.expect(std.mem.indexOf(u8, md, "ViewsConfig") == null);
    // Shown once.
    try t.expectEqual(@as(usize, 1), std.mem.count(u8, md, "pub const Ctx = struct"));
}
