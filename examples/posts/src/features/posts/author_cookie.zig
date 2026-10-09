//! Remembers the name typed in the form, so it is typed once. The value is
//! percent-encoded: a cookie cannot hold every character a name can.
const std = @import("std");
const spider = @import("spider");

const name = "author";
const one_year = 365 * 24 * 60 * 60;

/// The remembered name, or "" on a first visit.
pub fn read(c: *spider.Ctx) []const u8 {
    const raw = c.cookie(name) orelse return "";
    const copy = c.arena.dupe(u8, raw) catch return "";
    return std.Uri.percentDecodeInPlace(copy);
}

/// The value of a Set-Cookie header that remembers `author` for a year.
pub fn header(c: *spider.Ctx, author: []const u8) ![]const u8 {
    return c.setCookie(name, try encode(c.arena, author), .{ .max_age = one_year });
}

fn encode(arena: std.mem.Allocator, text: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    for (text) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.') {
            try out.append(arena, byte);
        } else {
            try out.print(arena, "%{X:0>2}", .{byte});
        }
    }
    return out.items;
}

test "encode keeps letters and escapes the rest" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const encoded = try encode(arena.allocator(), "Ana Ribeiro; é");
    try std.testing.expectEqualStrings("Ana%20Ribeiro%3B%20%C3%A9", encoded);

    const copy = try arena.allocator().dupe(u8, encoded);
    try std.testing.expectEqualStrings("Ana Ribeiro; é", std.Uri.percentDecodeInPlace(copy));
}
