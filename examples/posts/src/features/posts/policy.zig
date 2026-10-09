//! Who may do what to a post. The routes name these rules
//! (`.policy = Posts.route(.update)`), and so does the page that decides
//! whether to show the Edit button (`Posts.can(c, .update, &post)`).
const std = @import("std");
const spider = @import("spider");
const model = @import("model.zig");
const repository = @import("repository.zig");

pub const Posts = spider.policySet(model.Post, .{
    .name = "post",
    .load = load,
    .rules = .{
        .update = isAuthor,
        .delete = isAuthor,
    },
});

/// The post named by the :id of the path. Null (no such post, or an id
/// that is not a number) is the 404 page.
pub fn load(c: *spider.Ctx) !?model.Post {
    const text = c.params.get("id") orelse return null;
    const id = std.fmt.parseInt(i64, text, 10) catch return null;
    return repository.find(c.arena, id);
}

/// A post is changed by the account that wrote it. The sample posts have
/// no account (`user_id` is 0): nobody changes them.
fn isAuthor(c: *spider.Ctx, post: *const model.Post) bool {
    const signed_in = signedInId(c) orelse return false;
    return post.user_id == signed_in;
}

/// The id of the account that is signed in: the session carries it as text.
pub fn signedInId(c: *spider.Ctx) ?i64 {
    return std.fmt.parseInt(i64, c.userId() orelse return null, 10) catch null;
}
