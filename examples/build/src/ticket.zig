//! Uses a part this project asked for: `.qrcode = true` in build.zig.
const std = @import("std");
const spider = @import("spider");

test "a part that was asked for is there" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const qr = try spider.qrcode.QR.encodeAuto(arena.allocator(), "https://spiderme.org", .medium);
    try std.testing.expect(qr.size > 0);
}
