const std = @import("std");

/// A row of the posts table. `age` is how many seconds ago it was written.
pub const Post = struct {
    id: i64,
    title: []const u8,
    body: []const u8,
    author: []const u8,
    /// The account that wrote it; 0 when it belongs to no account.
    user_id: i64,
    age: i64,
};

/// What the form sends.
pub const Input = struct {
    title: []const u8 = "",
    body: []const u8 = "",
    author: []const u8 = "",

    /// The same input without the spaces around each field.
    pub fn trimmed(self: Input) Input {
        return .{
            .title = std.mem.trim(u8, self.title, " \t\r\n"),
            .body = std.mem.trim(u8, self.body, " \t\r\n"),
            .author = std.mem.trim(u8, self.author, " \t\r\n"),
        };
    }
};

/// One message per field; an empty message means the field is fine.
pub const Errors = struct {
    title: []const u8 = "",
    body: []const u8 = "",
    author: []const u8 = "",

    pub fn any(self: Errors) bool {
        return self.title.len + self.body.len + self.author.len > 0;
    }
};

pub const max_title = 120;
pub const max_author = 60;
pub const max_body = 10_000;

pub fn validate(input: Input) Errors {
    var errors: Errors = .{};
    if (input.title.len == 0) {
        errors.title = "Give the post a title.";
    } else if (input.title.len > max_title) {
        errors.title = "Keep the title under 120 characters.";
    }
    if (input.body.len == 0) {
        errors.body = "Write something in the body.";
    } else if (input.body.len > max_body) {
        errors.body = "Keep the body under 10,000 characters.";
    }
    if (input.author.len == 0) {
        errors.author = "Tell readers who wrote this.";
    } else if (input.author.len > max_author) {
        errors.author = "Keep the name under 60 characters.";
    }
    return errors;
}

test "validate accepts a complete post" {
    const errors = validate(.{ .title = "Hello", .body = "First post.", .author = "Ana" });
    try std.testing.expect(!errors.any());
}

test "validate names every empty field" {
    const errors = validate((Input{ .title = "  ", .body = "", .author = "\n" }).trimmed());
    try std.testing.expectEqualStrings("Give the post a title.", errors.title);
    try std.testing.expectEqualStrings("Write something in the body.", errors.body);
    try std.testing.expectEqualStrings("Tell readers who wrote this.", errors.author);
}

test "validate limits the length of the title and the name" {
    const long: [max_title + 1]u8 = @splat('a');
    const errors = validate(.{ .title = &long, .body = "x", .author = &long });
    try std.testing.expectEqualStrings("Keep the title under 120 characters.", errors.title);
    try std.testing.expectEqualStrings("Keep the name under 60 characters.", errors.author);
    try std.testing.expectEqualStrings("", errors.body);
}
