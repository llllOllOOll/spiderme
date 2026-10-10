//! The rules of the app, tested against a real PostgreSQL (`./test.sh`
//! starts one for the run). Each test uses a day of its own, so the tests
//! do not get in each other's way.
const std = @import("std");
const spider = @import("spider");
const features = @import("features");
const app_test = @import("app_test.zig");

const rooms = features.rooms.repository;
const bookings = features.bookings.repository;
const Input = features.bookings.model.Input;

/// A room of the sample data, by name.
fn roomId(arena: std.mem.Allocator, name: []const u8) !i64 {
    for (try rooms.all(arena)) |room| {
        if (std.mem.eql(u8, room.name, name)) return room.id;
    }
    return error.RoomNotFound;
}

fn booking(room_id: i64, day: []const u8, starts: []const u8, ends: []const u8) Input {
    return .{ .room_id = room_id, .day = day, .starts = starts, .ends = ends, .title = "Design review", .booked_by = "Ana Ribeiro" };
}

test "rooms: the sample rooms, by name, with their features as text" {
    _ = try app_test.running();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const all = try rooms.all(arena);
    try std.testing.expect(all.len >= 6);
    try std.testing.expectEqualStrings("Atlas", all[0].name);
    try std.testing.expectEqual(@as(i32, 12), all[0].capacity);
    try std.testing.expectEqualStrings("projector, video call, whiteboard", all[0].features);
}

test "rooms: filtered by the features they must have" {
    _ = try app_test.running();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // Every room that has a projector AND a whiteboard.
    const both = try rooms.withFeatures(arena, &.{ "projector", "whiteboard" });
    try std.testing.expectEqual(@as(usize, 2), both.len);
    try std.testing.expectEqualStrings("Atlas", both[0].name);
    try std.testing.expectEqualStrings("Workshop", both[1].name);

    // No room has a screen and a video call.
    try std.testing.expectEqual(@as(usize, 0), (try rooms.withFeatures(arena, &.{ "screen", "video call" })).len);
    // Nothing asked for: every room.
    try std.testing.expect((try rooms.withFeatures(arena, &.{})).len >= 6);
}

test "rooms: a name that is taken is NameTaken" {
    _ = try app_test.running();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    try std.testing.expectError(error.NameTaken, rooms.create(arena, .{ .name = "Atlas", .capacity = 4 }));
    const made = try rooms.create(arena, .{ .name = "Fir", .capacity = 3, .features = &.{"screen"} });
    try std.testing.expectEqualStrings("screen", made.features);
}

test "a booking is made held, and shows on its day" {
    _ = try app_test.running();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const birch = try roomId(arena, "Birch");

    const made = try bookings.create(arena, booking(birch, "2031-03-03", "11:00", "12:00"));
    try std.testing.expectEqualStrings("Birch", made.room);
    try std.testing.expectEqualStrings("2031-03-03", made.day);
    try std.testing.expectEqualStrings("11:00", made.starts);
    try std.testing.expectEqualStrings("12:00", made.ends);
    try std.testing.expectEqual(features.bookings.model.State.held, made.state);
    try std.testing.expectEqual(@as(?i32, 10), made.minutes_left);
    try std.testing.expect(made.note == null);

    const day = try bookings.forDay(arena, "2031-03-03");
    try std.testing.expectEqual(@as(usize, 1), day.len);
    try std.testing.expectEqual(made.id, day[0].id);
    try std.testing.expectEqual(@as(usize, 0), (try bookings.forDay(arena, "2031-03-04")).len);
}

test "a room cannot have two bookings at the same time" {
    _ = try app_test.running();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const birch = try roomId(arena, "Birch");
    const cedar = try roomId(arena, "Cedar");
    const day = "2031-03-10";

    const first = try bookings.create(arena, booking(birch, day, "11:00", "12:00"));

    // The same time, a part of it, or a time around it: all refused.
    try std.testing.expectError(error.SlotTaken, bookings.create(arena, booking(birch, day, "11:00", "12:00")));
    try std.testing.expectError(error.SlotTaken, bookings.create(arena, booking(birch, day, "11:30", "12:30")));
    try std.testing.expectError(error.SlotTaken, bookings.create(arena, booking(birch, day, "10:00", "13:00")));

    // What is in the way, for the message on the form.
    const taken = try bookings.overlapping(arena, birch, day, "10:00", "13:00");
    try std.testing.expectEqual(@as(usize, 1), taken.len);
    try std.testing.expectEqual(first.id, taken[0].id);

    // Right before, right after, another room, another day: all fine.
    _ = try bookings.create(arena, booking(birch, day, "10:00", "11:00"));
    _ = try bookings.create(arena, booking(birch, day, "12:00", "12:30"));
    _ = try bookings.create(arena, booking(cedar, day, "11:00", "12:00"));
    _ = try bookings.create(arena, booking(birch, "2031-03-11", "11:00", "12:00"));
    try std.testing.expectEqual(@as(usize, 4), (try bookings.forDay(arena, day)).len);
}

test "twenty requests for the same time: exactly one gets it" {
    _ = try app_test.running();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const birch = try roomId(arena, "Birch");

    const Race = struct {
        room: i64,
        won: std.atomic.Value(u32) = .init(0),
        refused: std.atomic.Value(u32) = .init(0),
        other: std.atomic.Value(u32) = .init(0),

        fn ask(race: *@This()) void {
            var mine: std.heap.ArenaAllocator = .init(std.heap.smp_allocator);
            defer mine.deinit();
            if (bookings.create(mine.allocator(), booking(race.room, "2031-03-17", "09:00", "10:00"))) |_| {
                _ = race.won.fetchAdd(1, .seq_cst);
            } else |err| {
                _ = (if (err == error.SlotTaken) &race.refused else &race.other).fetchAdd(1, .seq_cst);
            }
        }
    };
    var race: Race = .{ .room = birch };
    var threads: [20]std.Thread = undefined;
    for (&threads) |*t| t.* = try std.Thread.spawn(.{}, Race.ask, .{&race});
    for (threads) |t| t.join();

    try std.testing.expectEqual(@as(u32, 1), race.won.load(.seq_cst));
    try std.testing.expectEqual(@as(u32, 19), race.refused.load(.seq_cst));
    try std.testing.expectEqual(@as(u32, 0), race.other.load(.seq_cst));
    try std.testing.expectEqual(@as(usize, 1), (try bookings.forDay(arena, "2031-03-17")).len);
}

test "a booking outside the rules of the day is InvalidBooking" {
    _ = try app_test.running();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const birch = try roomId(arena, "Birch");
    const day = "2031-03-24";

    try std.testing.expectError(error.InvalidBooking, bookings.create(arena, booking(birch, day, "07:30", "09:00"))); // before 08:00
    try std.testing.expectError(error.InvalidBooking, bookings.create(arena, booking(birch, day, "19:00", "20:30"))); // after 20:00
    try std.testing.expectError(error.InvalidBooking, bookings.create(arena, booking(birch, day, "11:00", "10:00"))); // ends before it starts
    try std.testing.expectError(error.InvalidBooking, bookings.create(arena, booking(birch, day, "10:15", "11:00"))); // not on the half hour
    try std.testing.expectError(error.InvalidBooking, bookings.create(arena, booking(birch, "2031-02-30", "10:00", "11:00"))); // no such day
    var untitled = booking(birch, day, "10:00", "11:00");
    untitled.title = "";
    try std.testing.expectError(error.InvalidBooking, bookings.create(arena, untitled));
    try std.testing.expectError(error.NoSuchRoom, bookings.create(arena, booking(999_999, day, "10:00", "11:00")));

    try std.testing.expectEqual(@as(usize, 0), (try bookings.forDay(arena, day)).len);
}

test "confirm and cancel; a cancelled booking frees its time" {
    _ = try app_test.running();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const birch = try roomId(arena, "Birch");
    const day = "2031-03-31";

    const made = try bookings.create(arena, booking(birch, day, "14:00", "15:00"));
    try std.testing.expect(try bookings.confirm(arena, made.id));
    try std.testing.expect(!try bookings.confirm(arena, made.id)); // not held any more
    const confirmed = (try bookings.find(arena, made.id)).?;
    try std.testing.expectEqual(features.bookings.model.State.confirmed, confirmed.state);
    try std.testing.expect(confirmed.minutes_left == null);

    try std.testing.expectError(error.SlotTaken, bookings.create(arena, booking(birch, day, "14:00", "15:00")));
    try std.testing.expect(try bookings.cancel(arena, made.id));
    try std.testing.expect(!try bookings.cancel(arena, made.id));
    _ = try bookings.create(arena, booking(birch, day, "14:00", "15:00"));
}

test "a hold that ran out gives the time back" {
    _ = try app_test.running();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const birch = try roomId(arena, "Birch");
    const day = "2031-04-07";

    const made = try bookings.create(arena, booking(birch, day, "16:00", "17:00"));
    // Eleven minutes pass.
    try spider.pg.query(void, arena, "UPDATE bookings SET held_until = now() - interval '1 minute' WHERE id = $1", .{made.id});

    try std.testing.expect(!try bookings.confirm(arena, made.id)); // too late
    // Someone else books the same time: the dead hold steps aside in the
    // same transaction that makes the new booking.
    const next = try bookings.create(arena, booking(birch, day, "16:00", "17:00"));
    try std.testing.expectEqual(features.bookings.model.State.expired, (try bookings.find(arena, made.id)).?.state);
    try std.testing.expectEqual(features.bookings.model.State.held, next.state);

    // And the sweep that will run on a timer finds the ones nobody replaced.
    const other = try bookings.create(arena, booking(birch, day, "18:00", "19:00"));
    try spider.pg.query(void, arena, "UPDATE bookings SET held_until = now() - interval '1 minute' WHERE id = $1", .{other.id});
    const days = try bookings.expireStale(arena);
    try std.testing.expect(days.len >= 1);
    var found = false;
    for (days) |expired_day| {
        if (std.mem.eql(u8, expired_day, day)) found = true;
    }
    try std.testing.expect(found);
    // Nothing left to release.
    try std.testing.expectEqual(@as(usize, 0), (try bookings.expireStale(arena)).len);
    try std.testing.expectEqual(features.bookings.model.State.expired, (try bookings.find(arena, other.id)).?.state);
}
