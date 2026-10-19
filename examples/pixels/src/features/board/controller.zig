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

/// "board:" and the board as it is now (see `board.snapshot_len`).
fn snapshotMessage(out: *[snapshot_prefix.len + board.snapshot_len]u8, now_ms: i64) void {
    @memcpy(out[0..snapshot_prefix.len], snapshot_prefix);
    board.snapshot(out[snapshot_prefix.len..], now_ms);
}

/// The longest message read: "reset:" and a 64-character token.
const max_reset_message = 128;

/// The board's WebSocket (registered in src/main.zig): the whole board
/// first, then every valid paint goes to everyone on the "board" channel.
/// "reset:<PIXELS_RESET_TOKEN>" clears the board for everyone.
pub fn socket(ws: *spider.Ws) !void {
    try ws.join("board");
    var snap: [snapshot_prefix.len + board.snapshot_len]u8 = undefined;
    snapshotMessage(&snap, now(ws));
    try ws.send(&snap);

    // Everyone sees how many are painting, now and when this one leaves.
    ws.broadcastToFmt("board", "online:{d}", .{board.joined()});
    defer ws.broadcastToFmt("board", "online:{d}", .{board.left()});

    var limit: board.Limiter = .{};
    while (try ws.next()) |msg| {
        if (msg.type != .text) continue;
        if (!limit.allow(now(ws))) continue;
        if (msg.data.len <= max_reset_message and board.isReset(msg.data, board.reset_token)) {
            board.reset();
            snapshotMessage(&snap, now(ws));
            ws.broadcastTo("board", &snap);
            continue;
        }
        const p = board.parsePaint(msg.data) orelse continue;
        board.set(p, now(ws));
        ws.broadcastToFmt("board", "{d},{d},{d}", .{ p.x, p.y, p.color });
    }
}

fn now(ws: *spider.Ws) i64 {
    return std.Io.Clock.awake.now(ws.io).toMilliseconds();
}
