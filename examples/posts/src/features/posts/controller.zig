const std = @import("std");
const spider = @import("spider");
const model = @import("model.zig");
const repository = @import("repository.zig");
const present = @import("present.zig");
const Response = spider.Response;

pub fn home(c: *spider.Ctx) !Response {
    return c.redirect("/posts");
}

/// The feed. With ?q= it only lists the posts that match.
pub fn index(c: *spider.Ctx) !Response {
    const q = std.mem.trim(u8, c.queryDecoded("q") orelse "", " ");
    const posts = if (q.len > 0)
        try repository.search(c.arena, q)
    else
        try repository.list(c.arena);

    return c.view("posts/index", .{
        .title = "Posts",
        .q = q,
        .searching = q.len > 0,
        .posts = try present.cards(c.arena, posts),
    }, .{});
}

pub fn show(c: *spider.Ctx) !Response {
    const post = try load(c);
    return c.view("posts/show", .{
        .title = post.title,
        .post = try present.card(c.arena, post),
        // The body is Markdown. Spider's renderer escapes what the author
        // typed, so its HTML can go into the page as it is.
        .body = spider.RawHtml{ .html = try spider.zmd.parse(c.arena, post.body, .{}) },
    }, .{});
}

pub fn new(c: *spider.Ctx) !Response {
    return form(c, null, .{ .author = c.cookieDecoded("author") orelse "" }, .{});
}

pub fn create(c: *spider.Ctx) !Response {
    const input = (try c.parseForm(model.Input)).trimmed();
    const errors = model.validate(input);
    if (errors.any()) return form(c, null, input, errors);

    const id = try repository.create(c.arena, input);
    return saved(c, id, input.author);
}

pub fn edit(c: *spider.Ctx) !Response {
    const post = try load(c);
    return form(c, post.id, .{ .title = post.title, .body = post.body, .author = post.author }, .{});
}

pub fn update(c: *spider.Ctx) !Response {
    const post = try load(c);
    const input = (try c.parseForm(model.Input)).trimmed();
    const errors = model.validate(input);
    if (errors.any()) return form(c, post.id, input, errors);

    try repository.update(c.arena, post.id, input);
    return saved(c, post.id, input.author);
}

/// Asks before deleting. It is a page, so it works without JavaScript.
pub fn confirmDelete(c: *spider.Ctx) !Response {
    const post = try load(c);
    return c.view("posts/delete", .{
        .title = "Delete post",
        .post = try present.card(c.arena, post),
    }, .{});
}

pub fn delete(c: *spider.Ctx) !Response {
    const post = try load(c);
    try repository.delete(c.arena, post.id);
    return c.redirect("/posts");
}

/// Every post as a spreadsheet file the browser saves.
pub fn exportCsv(c: *spider.Ctx) !Response {
    const posts = try repository.list(c.arena);

    var csv: std.ArrayList(u8) = .empty;
    try csv.appendSlice(c.arena, "id,title,author\n");
    for (posts) |post| {
        try csv.print(c.arena, "{d},{s},{s}\n", .{
            post.id,
            try csvField(c.arena, post.title),
            try csvField(c.arena, post.author),
        });
    }

    return c.download(csv.items, .{
        .filename = "posts.csv",
        .content_type = spider.content_types.csv,
    });
}

/// `text` in quotes, with the quotes inside it doubled: what a CSV field
/// needs to hold commas, quotes and line breaks.
fn csvField(arena: std.mem.Allocator, text: []const u8) ![]const u8 {
    const doubled = try std.mem.replaceOwned(u8, arena, text, "\"", "\"\"");
    return std.fmt.allocPrint(arena, "\"{s}\"", .{doubled});
}

test "csvField: quotes around the text, quotes inside doubled" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectEqualStrings("\"Hello, world\"", try csvField(arena.allocator(), "Hello, world"));
    try std.testing.expectEqualStrings("\"a \"\"quoted\"\" word\"", try csvField(arena.allocator(), "a \"quoted\" word"));
}

/// The post named by the :id of the path. A missing post, or an id that is
/// not a number, is error.NotFound: the 404 page.
fn load(c: *spider.Ctx) !model.Post {
    const text = c.params.get("id") orelse return error.NotFound;
    const id = std.fmt.parseInt(i64, text, 10) catch return error.NotFound;
    return (try repository.find(c.arena, id)) orelse error.NotFound;
}

/// The form for a new post (`id` is null) or for an existing one. With
/// errors it answers 422 and keeps what was typed.
fn form(c: *spider.Ctx, id: ?i64, input: model.Input, errors: model.Errors) !Response {
    const heading: []const u8 = if (id == null) "New post" else "Edit post";
    return c.view("posts/form", .{
        .title = heading,
        .heading = heading,
        .action = if (id) |n| try std.fmt.allocPrint(c.arena, "/posts/{d}/update", .{n}) else "/posts/create",
        .back = if (id) |n| try std.fmt.allocPrint(c.arena, "/posts/{d}", .{n}) else "/posts",
        .back_label = if (id == null) "All posts" else "Back to the post",
        .submit = if (id == null) "Publish post" else "Save changes",
        .form = input,
        .errors = errors,
        .composing = true,
    }, .{ .status = if (errors.any()) .unprocessable_entity else .ok });
}

/// After a save: go to the post and remember who wrote it, for a year.
/// `.encode` lets the cookie hold any name (an accent, a semicolon).
fn saved(c: *spider.Ctx, id: i64, author: []const u8) !Response {
    const one_year = 365 * 24 * 60 * 60;
    const url = try std.fmt.allocPrint(c.arena, "/posts/{d}", .{id});
    return c.redirectWith(url, try c.withCookie("author", author, .{ .encode = true, .max_age = one_year }));
}
