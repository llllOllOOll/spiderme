//! The shared board: 48x48 color indexes kept in memory, and the paint
//! messages the clients send ("x,y,color").
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

var cells: [size * size]u8 = @splat(empty);
var lock: std.atomic.Mutex = .unlocked;

fn acquire() void {
    while (!lock.tryLock()) std.atomic.spinLoopHint();
}

/// Stores one pixel.
pub fn set(p: Paint) void {
    acquire();
    defer lock.unlock();
    cells[@as(usize, p.y) * size + p.x] = '0' + p.color;
}

/// Copies the whole board, row by row, one character per cell.
pub fn snapshot(out: *[size * size]u8) void {
    acquire();
    defer lock.unlock();
    out.* = cells;
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

/// Clears the board (tests).
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

test "a paint shows in the snapshot" {
    reset();
    defer reset();
    set(.{ .x = 2, .y = 1, .color = 4 });
    var out: [size * size]u8 = undefined;
    snapshot(&out);
    try t.expectEqual(@as(u8, '4'), out[1 * size + 2]);
    try t.expectEqual(empty, out[0]);
}
