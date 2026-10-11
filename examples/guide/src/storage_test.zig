//! content/docs/storage.md: files in a bucket (Cloudflare R2).
const std = @import("std");
const spider = @import("spider");
const run = @import("server.zig").run;

test "storage: the browser gets an address to upload to, signed for a few minutes" {
    const app = try spider.testing.start(run);
    var res = try app.request(.{ .method = "POST", .target = "/avatars/sign", .body = "" });
    defer res.deinit();
    try res.expectStatus(200);

    // The object's name is the app's, under the account's folder.
    try res.expectContains("\"key\":\"account-7/avatars/");
    // The address is the bucket's, and carries the signature and how long it lasts.
    try res.expectContains("\"upload_to\":\"https://0a1b2c3d4e5f.r2.cloudflarestorage.com/guide-files/account-7/avatars/");
    try res.expectContains("X-Amz-Expires=300");
    try res.expectContains("X-Amz-Signature=");
    // The secret key signs it and is not in it.
    try res.expectNotContains("a-secret-access-key");
    // Where the file will be seen, on the bucket's public domain.
    try res.expectContains("\"shown_at\":\"https://files.guide.example/account-7/avatars/");
}

test "storage: a private file is reached through an address that lasts a minute" {
    const app = try spider.testing.start(run);
    var res = try app.get("/invoices/2026-0042");
    defer res.deinit();
    try res.expectStatus(302);
    const to = res.header("Location").?;
    try std.testing.expect(std.mem.startsWith(u8, to, "https://0a1b2c3d4e5f.r2.cloudflarestorage.com/guide-files/account-7/invoices/2026-0042.pdf?"));
    try std.testing.expect(std.mem.indexOf(u8, to, "X-Amz-Expires=60") != null);
}

test "storage: a client without its account, keys or bucket is refused when it is made" {
    try std.testing.expectError(error.R2ConfigMissing, spider.r2.R2.init(std.testing.io, .{
        .account_id = "0a1b2c3d4e5f",
        .access_key = "an-access-key-id",
        .secret_key = "",
        .bucket = "guide-files",
    }));
}
