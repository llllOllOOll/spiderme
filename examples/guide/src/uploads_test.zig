//! content/docs/uploads.md: files coming in and going out.
const std = @import("std");
const spider = @import("spider");
const run = @import("server.zig").run;

// The smallest PNG there is: one transparent pixel.
const png = "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82";

/// What a browser sends for a form with a caption and one file.
fn form(arena: std.mem.Allocator, filename: []const u8, content_type: []const u8, bytes: []const u8) ![]const u8 {
    return std.fmt.allocPrint(arena, "--edge\r\n" ++
        "Content-Disposition: form-data; name=\"caption\"\r\n\r\n" ++
        "The team\r\n" ++
        "--edge\r\n" ++
        "Content-Disposition: form-data; name=\"photo\"; filename=\"{s}\"\r\n" ++
        "Content-Type: {s}\r\n\r\n" ++
        "{s}\r\n" ++
        "--edge--\r\n", .{ filename, content_type, bytes });
}

const multipart = &.{"Content-Type: multipart/form-data; boundary=edge"};

test "upload: a photo and its caption arrive together" {
    const app = try spider.testing.start(run);
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();

    var res = try app.request(.{ .method = "POST", .target = "/photos", .headers = multipart, .body = try form(arena_state.allocator(), "team.png", "image/png", png) });
    defer res.deinit();
    try res.expectStatus(201);
    try res.expectContains("\"caption\":\"The team\"");
    try res.expectContains("\"sent_as\":\"team.png\"");
}

test "upload: the app decides by the bytes, whatever the browser called the file" {
    const app = try spider.testing.start(run);
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();

    // Named and typed as a PNG, and it is a script.
    var res = try app.request(.{ .method = "POST", .target = "/photos", .headers = multipart, .body = try form(arena_state.allocator(), "team.png", "image/png", "<script>alert(1)</script>") });
    defer res.deinit();
    try res.expectStatus(422);
    try res.expectContains("Only PNG images.");
}

test "upload: a form without the file, and a body that is not a form" {
    const app = try spider.testing.start(run);

    var no_file = try app.request(.{ .method = "POST", .target = "/photos", .headers = multipart, .body = "--edge\r\nContent-Disposition: form-data; name=\"caption\"\r\n\r\nThe team\r\n--edge--\r\n" });
    defer no_file.deinit();
    try no_file.expectStatus(422);
    try no_file.expectContains("Choose a photo.");

    var not_a_form = try app.request(.{ .method = "POST", .target = "/photos", .headers = &.{"Content-Type: application/json"}, .body = "{}" });
    defer not_a_form.deinit();
    try not_a_form.expectStatus(400);
}

test "download: the browser saves the file under the name the app gives" {
    const app = try spider.testing.start(run);
    var res = try app.get("/photos/report");
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectHeader("Content-Type", "text/csv");
    try res.expectHeader("Content-Disposition", "attachment; filename=\"photos.csv\"");
    try res.expectHeader("X-Content-Type-Options", "nosniff");
    try std.testing.expectEqualStrings("caption,bytes\nThe team,20480\n", res.body);
}
