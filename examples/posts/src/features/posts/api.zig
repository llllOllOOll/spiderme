//! The JSON side of Posts: the same posts, for programs instead of
//! browsers. Its routes are the `api` group of routes.zig.
const std = @import("std");
const spider = @import("spider");
const model = @import("model.zig");
const repository = @import("repository.zig");
const Response = spider.Response;

/// A post as the API shows it.
const PostJson = struct {
    id: i64,
    title: []const u8,
    body: []const u8,
    author: []const u8,
};

/// GET /api/posts: every post, newest first. `?q=` searches, `?limit=`
/// cuts the list.
pub fn list(c: *spider.Ctx) !Response {
    const q = c.queryDecoded("q") orelse "";
    const posts = if (q.len > 0)
        try repository.search(c.arena, q)
    else
        try repository.list(c.arena);

    var limit = posts.len;
    if (c.query("limit")) |text| {
        limit = std.fmt.parseInt(usize, text, 10) catch {
            c.setErrorDetail("limit must be a whole number");
            return error.BadRequest;
        };
    }

    const shown = posts[0..@min(limit, posts.len)];
    const out = try c.arena.alloc(PostJson, shown.len);
    for (shown, out) |post, *json| json.* = asJson(post);
    return c.json(.{ .posts = out }, .{});
}

/// GET /api/posts/:id. The id arrives as a number: a value that is not
/// one answers 400 before this function runs.
pub fn show(id: spider.Path(i64, "id"), c: *spider.Ctx) !Response {
    const post = (try repository.find(c.arena, id.value)) orelse return error.NotFound;
    return c.json(asJson(post), .{});
}

/// POST /api/posts, with the post as JSON in the body.
pub fn create(c: *spider.Ctx) !Response {
    const input = (try c.bodyJson(model.Input)).trimmed();
    const errors = model.validate(input);
    if (errors.any()) return c.json(.{ .errors = errors }, .{ .status = .unprocessable_entity });

    // A program holds the key, not an account: the post belongs to nobody.
    const id = try repository.create(c.arena, input, null);
    const location = try std.fmt.allocPrint(c.arena, "/api/posts/{d}", .{id});
    return c.json(.{ .id = id }, .{
        .status = .created,
        .headers = try c.arena.dupe([2][]const u8, &.{.{ "Location", location }}),
    });
}

fn asJson(post: model.Post) PostJson {
    return .{ .id = post.id, .title = post.title, .body = post.body, .author = post.author };
}

// ── middlewares of the API ──────────────────────────────────────────────

/// Lets a request through only when it carries the API key in the
/// X-Api-Key header. Anything else ends here with 401: the handler never
/// runs.
pub fn requireKey(c: *spider.Ctx, next: spider.NextFn) anyerror!Response {
    const sent = c.header("X-Api-Key") orelse return error.Unauthorized;
    if (!std.mem.eql(u8, sent, apiKey())) return error.Unauthorized;
    return next(c);
}

/// Tells browsers and proxies not to keep a copy of the answer. It calls
/// `next` first, then adds a header to what came back.
pub fn noStore(c: *spider.Ctx, next: spider.NextFn) anyerror!Response {
    var res = try next(c);
    const headers = try c.arena.alloc([2][]const u8, res.headers.len + 1);
    @memcpy(headers[0..res.headers.len], res.headers);
    headers[res.headers.len] = .{ "Cache-Control", "no-store" };
    res.headers = headers;
    return res;
}

/// The key clients must send: POSTS_API_KEY from the environment or .env.
/// Without one the API uses "dev-key", fine on your own machine only.
fn apiKey() []const u8 {
    const Once = struct {
        var key: ?[]const u8 = null;
    };
    if (Once.key == null) Once.key = spider.env.getOr("POSTS_API_KEY", "dev-key");
    return Once.key.?;
}
