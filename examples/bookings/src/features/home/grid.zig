//! The day as the page draws it: for each room, 24 half hours that are
//! free, over or taken, and one block per booking placed by the slot it
//! starts at and by how many slots it lasts. Plain functions: no database,
//! no request.
const std = @import("std");
const Booking = @import("../bookings/model.zig").Booking;
const Room = @import("../rooms/model.zig").Room;
const Day = @import("../bookings/model.zig").Day;

/// Half hours in a day of the office: 08:00 to 20:00.
pub const slots = 24;
const opens_at = 8 * 60;

/// "09:30" -> 3 (the fourth half hour after 08:00). null for a time that is
/// not on a half hour of the day; 20:00 is 24, the end of the last slot.
pub fn slotOf(time: []const u8) ?usize {
    if (time.len != 5 or time[2] != ':') return null;
    const hour = std.fmt.parseInt(u32, time[0..2], 10) catch return null;
    const minute = std.fmt.parseInt(u32, time[3..5], 10) catch return null;
    if (minute != 0 and minute != 30) return null;
    const minutes = hour * 60 + minute;
    if (minutes < opens_at or minutes > opens_at + slots * 30) return null;
    return (minutes - opens_at) / 30;
}

/// 3 -> "09:30".
pub fn timeOf(arena: std.mem.Allocator, slot: usize) ![]const u8 {
    const minutes = opens_at + slot * 30;
    return std.fmt.allocPrint(arena, "{d:0>2}:{d:0>2}", .{ minutes / 60, minutes % 60 });
}

/// One half hour of one room.
pub const Cell = struct {
    /// "free": a link to book it. "past": over, or on a day that is over.
    /// "taken": under a booking.
    kind: []const u8,
    /// " ui-hr" on the last half of an hour (the stronger line), else "".
    line: []const u8,
    time: []const u8,
    href: []const u8,
};

/// One booking, as a block over the cells.
pub const Block = struct {
    id: i64,
    /// The class that draws it: booked, mine, held, held and mine.
    look: []const u8,
    /// The slot it starts at and how many it lasts.
    at: usize,
    len: usize,
    title: []const u8,
    /// "You", or the name of who booked.
    who: []const u8,
    /// "09:00–10:30"
    range: []const u8,
    held: bool,
    minutes_left: i32,
    /// What fits depends on the height: one slot shows the title alone,
    /// two add who booked, three or more add the time.
    one: bool,
    show_who: bool,
    show_range: bool,
    label: []const u8,
    /// " ui-cell-changed" for a booking made a moment ago, else "".
    changed: []const u8,
    fresh: bool,
};

pub const Column = struct {
    id: i64,
    name: []const u8,
    seats: []const u8,
    /// " ui-on" for the room a phone shows, else "".
    on: []const u8,
    cells: []Cell,
    blocks: []Block,
};

/// Builds the columns of `day`. `viewer` is the account looking, when
/// someone is signed in: their bookings are drawn as theirs. `shown` is the
/// room a phone shows (null: the first).
pub fn columns(
    arena: std.mem.Allocator,
    day: Day,
    rooms: []const Room,
    bookings: []const Booking,
    viewer: ?i64,
    shown: ?i64,
) ![]Column {
    const out = try arena.alloc(Column, rooms.len);
    for (rooms, out, 0..) |room, *column, index| {
        var taken: [slots]bool = @splat(false);
        var blocks: std.ArrayList(Block) = .empty;
        for (bookings) |b| {
            if (b.room_id != room.id) continue;
            const at = slotOf(b.starts) orelse continue;
            const end = slotOf(b.ends) orelse continue;
            if (end <= at) continue;
            for (at..end) |slot| taken[slot] = true;

            const mine = viewer != null and b.user_id != null and viewer.? == b.user_id.?;
            const held = b.state == .held;
            const who = if (mine) "You" else b.booked_by;
            const len = end - at;
            try blocks.append(arena, .{
                .id = b.id,
                .look = if (held and mine) "ui-cell-held ui-is-mine" else if (held) "ui-cell-held" else if (mine) "ui-cell-mine" else "ui-cell-booked",
                .at = at,
                .len = len,
                .title = b.title,
                .who = who,
                .range = try std.fmt.allocPrint(arena, "{s}–{s}", .{ b.starts, b.ends }),
                .held = held,
                .minutes_left = b.minutes_left orelse 0,
                .one = len == 1,
                .show_who = len >= 2 and !held,
                .show_range = len >= 3,
                .label = try std.fmt.allocPrint(arena, "{s}, {s} to {s}, {s} by {s}", .{
                    b.title, b.starts, b.ends, if (held) "held" else "booked", if (mine) "you" else b.booked_by,
                }),
                .changed = if (b.fresh) " ui-cell-changed" else "",
                .fresh = b.fresh,
            });
        }

        const cells = try arena.alloc(Cell, slots);
        for (cells, 0..) |*cell, slot| {
            const time = try timeOf(arena, slot);
            // A slot is over once it has started.
            const over = day.is_past or (day.is_today and opens_at + @as(i32, @intCast(slot)) * 30 <= day.now_minutes);
            cell.* = .{
                .kind = if (taken[slot]) "taken" else if (over) "past" else "free",
                .line = if (slot % 2 == 1) " ui-hr" else "",
                .time = time,
                .href = try std.fmt.allocPrint(arena, "/bookings/new?room={d}&date={s}&start={s}", .{ room.id, day.day, time }),
            };
        }

        column.* = .{
            .id = room.id,
            .name = room.name,
            .seats = try std.fmt.allocPrint(arena, "{d} {s}", .{ room.capacity, if (room.capacity == 1) "seat" else "seats" }),
            .on = if ((shown == null and index == 0) or (shown != null and shown.? == room.id)) " ui-on" else "",
            .cells = cells,
            .blocks = try blocks.toOwnedSlice(arena),
        };
    }
    return out;
}

/// Where the line of the current time goes, in steps of five minutes from
/// 08:00 (0 to 143); null outside the hours of the office.
pub fn nowStep(now_minutes: i32) ?usize {
    if (now_minutes < opens_at or now_minutes >= opens_at + slots * 30) return null;
    return @intCast(@divFloor(now_minutes - opens_at, 5));
}

const testing = std.testing;

test "slotOf and timeOf" {
    try testing.expectEqual(@as(?usize, 0), slotOf("08:00"));
    try testing.expectEqual(@as(?usize, 3), slotOf("09:30"));
    try testing.expectEqual(@as(?usize, 24), slotOf("20:00"));
    try testing.expectEqual(@as(?usize, null), slotOf("07:30"));
    try testing.expectEqual(@as(?usize, null), slotOf("20:30"));
    try testing.expectEqual(@as(?usize, null), slotOf("09:15"));
    try testing.expectEqual(@as(?usize, null), slotOf("soon"));

    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    try testing.expectEqualStrings("08:00", try timeOf(arena.allocator(), 0));
    try testing.expectEqualStrings("09:30", try timeOf(arena.allocator(), 3));
    try testing.expectEqualStrings("19:30", try timeOf(arena.allocator(), 23));
}

test "columns: a booking is one block, its slots are taken, earlier today is over" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const rooms = [_]Room{
        .{ .id = 1, .name = "Atlas", .capacity = 12, .features = &.{"projector"} },
        .{ .id = 2, .name = "Echo", .capacity = 1, .features = &.{} },
    };
    const bookings = [_]Booking{
        .{ .id = 10, .room_id = 1, .room = "Atlas", .day = "2026-10-12", .starts = "09:00", .ends = "10:30", .title = "Quarterly planning", .booked_by = "Ana Ribeiro", .user_id = 7, .state = .confirmed },
        .{ .id = 11, .room_id = 1, .room = "Atlas", .day = "2026-10-12", .starts = "14:00", .ends = "14:30", .title = "1:1", .booked_by = "Marcus Lee", .user_id = 8, .state = .held, .minutes_left = 7 },
    };
    // Today, at 10:36.
    const day: Day = .{ .day = "2026-10-12", .label = "Monday, 12 October", .prev = "2026-10-11", .next = "2026-10-13", .is_today = true, .is_past = false, .now = "10:36", .now_minutes = 10 * 60 + 36 };

    const cols = try columns(arena, day, &rooms, &bookings, 7, null);
    try testing.expectEqual(@as(usize, 2), cols.len);
    try testing.expectEqualStrings("12 seats", cols[0].seats);
    try testing.expectEqualStrings("1 seat", cols[1].seats);
    try testing.expectEqualStrings(" ui-on", cols[0].on);
    try testing.expectEqualStrings("", cols[1].on);

    const atlas = cols[0];
    try testing.expectEqual(@as(usize, 2), atlas.blocks.len);
    // Ana's own booking: three slots from 09:00, drawn as hers, with the time.
    try testing.expectEqual(@as(usize, 2), atlas.blocks[0].at);
    try testing.expectEqual(@as(usize, 3), atlas.blocks[0].len);
    try testing.expectEqualStrings("ui-cell-mine", atlas.blocks[0].look);
    try testing.expectEqualStrings("You", atlas.blocks[0].who);
    try testing.expect(atlas.blocks[0].show_range);
    // Someone else's hold: one slot, the title alone.
    try testing.expectEqualStrings("ui-cell-held", atlas.blocks[1].look);
    try testing.expect(atlas.blocks[1].one);
    try testing.expectEqualStrings("1:1, 14:00 to 14:30, held by Marcus Lee", atlas.blocks[1].label);

    try testing.expectEqualStrings("past", atlas.cells[0].kind); // 08:00, over
    try testing.expectEqualStrings("taken", atlas.cells[2].kind); // 09:00, under the booking
    try testing.expectEqualStrings("past", atlas.cells[5].kind); // 10:30 has started
    try testing.expectEqualStrings("free", atlas.cells[6].kind); // 11:00
    try testing.expectEqualStrings("taken", atlas.cells[12].kind); // 14:00
    try testing.expectEqualStrings("/bookings/new?room=1&date=2026-10-12&start=11:00", atlas.cells[6].href);
    try testing.expectEqualStrings(" ui-hr", atlas.cells[1].line);

    // The same day seen by nobody, as a day that is over: nothing to book.
    var over = day;
    over.is_today = false;
    over.is_past = true;
    const past = try columns(arena, over, &rooms, &bookings, null, 2);
    try testing.expectEqualStrings("past", past[1].cells[23].kind);
    try testing.expectEqualStrings("ui-cell-booked", past[0].blocks[0].look);
    try testing.expectEqualStrings(" ui-on", past[1].on);
}

test "nowStep: five-minute steps from 08:00, nothing outside the day" {
    try testing.expectEqual(@as(?usize, 0), nowStep(8 * 60));
    try testing.expectEqual(@as(?usize, 31), nowStep(10 * 60 + 36));
    try testing.expectEqual(@as(?usize, null), nowStep(7 * 60 + 59));
    try testing.expectEqual(@as(?usize, null), nowStep(20 * 60));
}
