const std = @import("std");
const spider = @import("spider");
const board = @import("board.zig");
const qr = @import("qr.zig");

/// The shared pixel board, with a QR code of its own address.
pub fn index(c: *spider.Ctx) !spider.Response {
    const url = try qr.pageUrl(c);
    return c.view("board/index", .{
        .title = "Pixels",
        .url = url,
        .qr = spider.RawHtml{ .html = try qr.svg(c.arena, url) },
    }, .{});
}

const snapshot_prefix = "board:";

/// The board's WebSocket (registered in src/main.zig): the whole board
/// first, then every valid paint goes to everyone on the "board" channel.
pub fn socket(ws: *spider.Ws) !void {
    try ws.join("board");
    var snap: [snapshot_prefix.len + board.size * board.size]u8 = undefined;
    @memcpy(snap[0..snapshot_prefix.len], snapshot_prefix);
    board.snapshot(snap[snapshot_prefix.len..]);
    try ws.send(&snap);

    // Everyone sees how many are painting, now and when this one leaves.
    ws.broadcastToFmt("board", "online:{d}", .{board.joined()});
    defer ws.broadcastToFmt("board", "online:{d}", .{board.left()});

    var limit: board.Limiter = .{};
    while (try ws.next()) |msg| {
        if (msg.type != .text) continue;
        const p = board.parsePaint(msg.data) orelse continue;
        if (!limit.allow(std.Io.Clock.awake.now(ws.io).toMilliseconds())) continue;
        board.set(p);
        ws.broadcastToFmt("board", "{d},{d},{d}", .{ p.x, p.y, p.color });
    }
}
