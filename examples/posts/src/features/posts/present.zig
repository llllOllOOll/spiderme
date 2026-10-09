//! Turns a post into what the templates show: initials for the avatar, a
//! short excerpt, "2 hours ago".
const std = @import("std");
const model = @import("model.zig");

/// A post as the feed and the post page show it.
pub const Card = struct {
    id: i64,
    title: []const u8,
    author: []const u8,
    initials: []const u8,
    /// Picks the avatar color: the class is ui-avatar-<tone>.
    tone: []const u8,
    written: []const u8,
    excerpt: []const u8,
};

pub fn card(arena: std.mem.Allocator, post: model.Post) !Card {
    return .{
        .id = post.id,
        .title = post.title,
        .author = post.author,
        .initials = try initials(arena, post.author),
        .tone = tone(post.author),
        .written = try written(arena, post.age),
        .excerpt = excerpt(post.body),
    };
}

pub fn cards(arena: std.mem.Allocator, posts: []const model.Post) ![]Card {
    const out = try arena.alloc(Card, posts.len);
    for (posts, out) |post, *c| c.* = try card(arena, post);
    return out;
}

/// "Ana Ribeiro" is "AR", "Tom" is "T".
pub fn initials(arena: std.mem.Allocator, name: []const u8) ![]const u8 {
    var words = std.mem.tokenizeScalar(u8, name, ' ');
    const first = words.next() orelse return "?";
    var last: ?[]const u8 = null;
    while (words.next()) |word| last = word;

    var out: std.ArrayList(u8) = .empty;
    try appendFirstLetter(arena, &out, first);
    if (last) |word| try appendFirstLetter(arena, &out, word);
    return if (out.items.len == 0) "?" else out.items;
}

fn appendFirstLetter(arena: std.mem.Allocator, out: *std.ArrayList(u8), word: []const u8) !void {
    // Skip what is not a letter: the quote in "Silva", a parenthesis.
    var start: usize = 0;
    while (start < word.len and word[start] < 0x80 and !std.ascii.isAlphanumeric(word[start])) start += 1;
    if (start == word.len) return;

    const len = std.unicode.utf8ByteSequenceLength(word[start]) catch 1;
    const letter = word[start..@min(start + len, word.len)];
    if (letter.len == 1) {
        try out.append(arena, std.ascii.toUpper(letter[0]));
    } else {
        try out.appendSlice(arena, letter);
    }
}

/// The same name always gets the same one of the four avatar colors.
pub fn tone(name: []const u8) []const u8 {
    var hash: u32 = 0;
    for (name) |byte| hash = hash *% 31 +% byte;
    return ([_][]const u8{ "peach", "lilac", "sand", "mint" })[hash % 4];
}

/// How long ago, in words, from an age in seconds.
pub fn written(arena: std.mem.Allocator, age: i64) ![]const u8 {
    const minute = 60;
    const hour = 60 * minute;
    const day = 24 * hour;
    const week = 7 * day;

    if (age < minute) return "Just now";
    if (age < hour) return count(arena, @divFloor(age, minute), "minute");
    if (age < day) return count(arena, @divFloor(age, hour), "hour");
    if (age < 2 * day) return "Yesterday";
    if (age < week) return count(arena, @divFloor(age, day), "day");
    if (age < 2 * week) return "Last week";
    return count(arena, @divFloor(age, week), "week");
}

fn count(arena: std.mem.Allocator, n: i64, unit: []const u8) ![]const u8 {
    const plural: []const u8 = if (n == 1) "" else "s";
    return std.fmt.allocPrint(arena, "{d} {s}{s} ago", .{ @as(u64, @intCast(n)), unit, plural });
}

/// The first paragraph of the body.
pub fn excerpt(body: []const u8) []const u8 {
    const end = std.mem.indexOf(u8, body, "\n\n") orelse body.len;
    return std.mem.trim(u8, body[0..end], " \r\n");
}

test "initials take the first and the last word" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expectEqualStrings("AR", try initials(a, "Ana Ribeiro"));
    try std.testing.expectEqualStrings("AR", try initials(a, "ana de souza ribeiro"));
    try std.testing.expectEqualStrings("T", try initials(a, "Tom"));
    try std.testing.expectEqualStrings("ÉL", try initials(a, "Émile Laurent"));
    try std.testing.expectEqualStrings("ZS", try initials(a, "Zé da \"Silva\""));
    try std.testing.expectEqualStrings("?", try initials(a, "  "));
    try std.testing.expectEqualStrings("?", try initials(a, "--"));
}

test "tone is stable for a name" {
    try std.testing.expectEqualStrings("peach", tone("Ana Ribeiro"));
    try std.testing.expectEqualStrings("peach", tone("Ana Ribeiro"));
    try std.testing.expectEqualStrings("mint", tone("Marcus Lee"));
}

test "written says how long ago" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expectEqualStrings("Just now", try written(a, 5));
    try std.testing.expectEqualStrings("1 minute ago", try written(a, 60));
    try std.testing.expectEqualStrings("2 hours ago", try written(a, 2 * 3600 + 10));
    try std.testing.expectEqualStrings("Yesterday", try written(a, 24 * 3600));
    try std.testing.expectEqualStrings("3 days ago", try written(a, 3 * 24 * 3600));
    try std.testing.expectEqualStrings("Last week", try written(a, 7 * 24 * 3600));
    try std.testing.expectEqualStrings("3 weeks ago", try written(a, 21 * 24 * 3600));
}

test "excerpt is the first paragraph" {
    try std.testing.expectEqualStrings("One line.", excerpt("One line.\n\n## More\n\ntext"));
    try std.testing.expectEqualStrings("Only this.", excerpt("Only this."));
}
