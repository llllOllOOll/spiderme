//! The shared board: 48x48 color indexes kept in memory, and the paint
//! messages the clients send ("x,y,color"). A pixel lasts 15 minutes:
//! the board clears itself, nobody has to watch it.
const std = @import("std");

pub const size = 48;
pub const colors = 8;
/// A cell nobody painted yet (the others hold '0'..'7').
pub const empty: u8 = '-';

pub const Paint = struct { x: u8, y: u8, color: u8 };

/// The longest paint message ("47,47,7" is 7 bytes); longer ones are
/// dropped unread.
pub const max_message = 16;

/// Reads "x,y,color". Null when the message is malformed, too long, out of
/// the board or names an unknown color.
pub fn parsePaint(text: []const u8) ?Paint {
    if (text.len > max_message) return null;
    var it = std.mem.splitScalar(u8, text, ',');
    const x = number(it.next()) orelse return null;
    const y = number(it.next()) orelse return null;
    const color = number(it.next()) orelse return null;
    if (it.next() != null) return null;
    if (x >= size or y >= size or color >= colors) return null;
    return .{ .x = x, .y = y, .color = color };
}

fn number(part: ?[]const u8) ?u8 {
    const p = part orelse return null;
    return std.fmt.parseInt(u8, p, 10) catch null;
}

/// At most `per_second` paints per connection in each one-second window;
/// the extra ones are dropped (the board is open to anyone online).
pub const Limiter = struct {
    per_second: u32 = 30,
    window_ms: i64 = 0,
    count: u32 = 0,

    /// Whether one more paint is allowed at `now_ms`.
    pub fn allow(self: *Limiter, now_ms: i64) bool {
        if (now_ms - self.window_ms >= 1000) {
            self.window_ms = now_ms;
            self.count = 0;
        }
        if (self.count >= self.per_second) return false;
        self.count += 1;
        return true;
    }
};

/// How long a pixel stays on the board.
pub const lifetime_ms: i64 = 15 * 60 * 1000;
/// The unit of the time left in a snapshot: 15 seconds, so 15 minutes are
/// 60 steps, one character each.
pub const step_ms: i64 = 15 * 1000;

/// A snapshot: one color character per cell ('-' or '0'..'7'), then one
/// character per cell with the time it has left, '0' + steps of 15 s
/// rounded up ('0' for an empty cell). The clients clear each pixel when
/// its time is up, all at the same moment, with no message from here.
pub const snapshot_len = 2 * size * size;

var cells: [size * size]u8 = @splat(empty);
var painted_at: [size * size]i64 = @splat(0);
var lock: std.atomic.Mutex = .unlocked;

fn acquire() void {
    while (!lock.tryLock()) std.atomic.spinLoopHint();
}

/// Stores one pixel, painted at `now_ms`.
pub fn set(p: Paint, now_ms: i64) void {
    acquire();
    defer lock.unlock();
    const i = @as(usize, p.y) * size + p.x;
    cells[i] = '0' + p.color;
    painted_at[i] = now_ms;
}

/// Writes the board as it is at `now_ms` (see `snapshot_len`); pixels whose
/// time is up are dropped here.
pub fn snapshot(out: *[snapshot_len]u8, now_ms: i64) void {
    acquire();
    defer lock.unlock();
    for (&cells, &painted_at, 0..) |*cell, at, i| {
        const remaining = at + lifetime_ms - now_ms;
        if (cell.* != empty and remaining <= 0) cell.* = empty;
        out[i] = cell.*;
        out[size * size + i] = if (cell.* == empty) '0' else '0' + @as(u8, @intCast(@divFloor(remaining + step_ms - 1, step_ms)));
    }
}

/// The token that clears the whole board ("reset:<token>" on the socket),
/// from PIXELS_RESET_TOKEN; null turns clearing off.
pub var reset_token: ?[]const u8 = null;

/// Whether `text` is "reset:" followed by the reset token. The comparison
/// takes the same time whatever the guess.
pub fn isReset(text: []const u8, token: ?[]const u8) bool {
    const want = token orelse return false;
    if (want.len == 0 or !std.mem.startsWith(u8, text, "reset:")) return false;
    const Sha256 = std.crypto.hash.sha2.Sha256;
    var a: [Sha256.digest_length]u8 = undefined;
    var b: [Sha256.digest_length]u8 = undefined;
    Sha256.hash(text["reset:".len..], &a, .{});
    Sha256.hash(want, &b, .{});
    return std.crypto.timing_safe.eql([Sha256.digest_length]u8, a, b);
}

var online = std.atomic.Value(u32).init(0);

/// One more open board connection; returns how many there are now.
pub fn joined() u32 {
    return online.fetchAdd(1, .monotonic) + 1;
}

/// One board connection fewer; returns how many there are now.
pub fn left() u32 {
    return online.fetchSub(1, .monotonic) - 1;
}

/// Clears the whole board.
pub fn reset() void {
    acquire();
    defer lock.unlock();
    cells = @splat(empty);
}

const t = std.testing;

test "a paint message is x,y,color" {
    try t.expectEqual(Paint{ .x = 3, .y = 47, .color = 7 }, parsePaint("3,47,7").?);
}

test "out of the board, unknown colors and malformed messages are refused" {
    try t.expect(parsePaint("48,0,1") == null);
    try t.expect(parsePaint("0,48,1") == null);
    try t.expect(parsePaint("0,0,8") == null);
    try t.expect(parsePaint("-1,0,1") == null);
    try t.expect(parsePaint("1,2") == null);
    try t.expect(parsePaint("1,2,3,4") == null);
    try t.expect(parsePaint("a,b,c") == null);
    try t.expect(parsePaint("") == null);
    try t.expect(parsePaint("1,2,3            ") == null);
}

test "a connection paints at most 30 times a second" {
    var limit: Limiter = .{};
    var allowed: u32 = 0;
    for (0..100) |_| {
        if (limit.allow(5_000)) allowed += 1;
    }
    try t.expectEqual(@as(u32, 30), allowed);
    try t.expect(!limit.allow(5_999));
    try t.expect(limit.allow(6_000));
}

test "the online counter goes up and down" {
    const before = joined();
    try t.expectEqual(before - 1, left());
}

test "a paint shows in the snapshot with the time it has left" {
    reset();
    defer reset();
    set(.{ .x = 2, .y = 1, .color = 4 }, 1_000);
    var out: [snapshot_len]u8 = undefined;
    snapshot(&out, 1_000);
    try t.expectEqual(@as(u8, '4'), out[1 * size + 2]);
    try t.expectEqual(@as(u8, '0' + 60), out[size * size + 1 * size + 2]);
    try t.expectEqual(empty, out[0]);
    try t.expectEqual(@as(u8, '0'), out[size * size]);

    // One second later, 14:59 are left: still 60 steps, rounded up.
    snapshot(&out, 2_000);
    try t.expectEqual(@as(u8, '0' + 60), out[size * size + 1 * size + 2]);
    // With 10 s left, one step.
    snapshot(&out, 1_000 + lifetime_ms - 10_000);
    try t.expectEqual(@as(u8, '1'), out[size * size + 1 * size + 2]);
}

test "a pixel is gone after 15 minutes" {
    reset();
    defer reset();
    set(.{ .x = 0, .y = 0, .color = 1 }, 0);
    set(.{ .x = 1, .y = 0, .color = 2 }, 60_000);
    var out: [snapshot_len]u8 = undefined;
    snapshot(&out, lifetime_ms);
    try t.expectEqual(empty, out[0]);
    try t.expectEqual(@as(u8, '0'), out[size * size]);
    try t.expectEqual(@as(u8, '2'), out[1]);
}

test "reset clears every pixel" {
    set(.{ .x = 5, .y = 5, .color = 3 }, 0);
    reset();
    var out: [snapshot_len]u8 = undefined;
    snapshot(&out, 0);
    for (out[0 .. size * size]) |c| try t.expectEqual(empty, c);
}

test "only the right token clears the board" {
    try t.expect(isReset("reset:s3cret", "s3cret"));
    try t.expect(!isReset("reset:wrong", "s3cret"));
    try t.expect(!isReset("reset:", "s3cret"));
    try t.expect(!isReset("s3cret", "s3cret"));
    try t.expect(!isReset("reset:s3cret", null));
    try t.expect(!isReset("reset:", ""));
}
