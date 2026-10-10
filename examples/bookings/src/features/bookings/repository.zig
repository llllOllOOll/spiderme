const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("model.zig");

const columns =
    \\b.id, b.room_id, r.name AS room,
    \\b.day::text AS day,
    \\to_char(b.starts, 'HH24:MI') AS starts,
    \\to_char(b.ends, 'HH24:MI') AS ends,
    \\b.title, b.note, b.booked_by, b.user_id, b.state,
    \\CASE WHEN b.state = 'held'
    \\     THEN greatest(0, ceil(extract(epoch FROM b.held_until - now()) / 60))::integer
    \\END AS minutes_left
;
const from = " FROM bookings b JOIN rooms r ON r.id = b.room_id ";

/// The bookings that take a room on `day` ("2026-10-12"): held and
/// confirmed ones, by room and by time.
pub fn forDay(arena: std.mem.Allocator, day: []const u8) ![]model.Booking {
    const sql = "SELECT " ++ columns ++ from ++
        "WHERE b.day = $1::date AND b.state IN ('held', 'confirmed') ORDER BY r.name, b.starts";
    return db.query(model.Booking, arena, sql, .{day});
}

pub fn find(arena: std.mem.Allocator, id: i64) !?model.Booking {
    return db.queryOne(model.Booking, arena, "SELECT " ++ columns ++ from ++ "WHERE b.id = $1", .{id});
}

/// Why a booking could not be made.
pub const CreateError = error{
    /// The room already has a booking in that time.
    SlotTaken,
    /// Outside 08:00-20:00, not on the half hour, the end before the
    /// start, or a title that is empty or too long.
    InvalidBooking,
    /// No room with that id.
    NoSuchRoom,
};

/// Makes a booking, held for `model.hold_minutes`. error.SlotTaken when the
/// room is not free then: the database decides, so two requests for the
/// same time cannot both get it.
pub fn create(arena: std.mem.Allocator, input: model.Input) !model.Booking {
    const Work = struct { arena: std.mem.Allocator, input: model.Input };
    // Two statements that must both happen or neither: a hold that ran out
    // is released, then the new booking takes the time. One transaction,
    // on one connection.
    const id = db.transaction(i64, Work{ .arena = arena, .input = input }, struct {
        fn run(tx: *db.Transaction, work: Work) !i64 {
            const in = work.input;
            try tx.query(void, work.arena,
                \\UPDATE bookings SET state = 'expired'
                \\WHERE room_id = $1 AND day = $2::date AND state = 'held' AND held_until < now()
            , .{ in.room_id, in.day });
            return tx.query(i64, work.arena,
                \\INSERT INTO bookings (room_id, day, starts, ends, title, note, booked_by, user_id, held_until)
                \\VALUES ($1, $2::date, $3::time, $4::time, $5, $6, $7, $8, now() + make_interval(mins => $9))
                \\RETURNING id
            , .{ in.room_id, in.day, in.starts, in.ends, in.title, in.note, in.booked_by, in.user_id, @as(i32, model.hold_minutes) });
        }
    }.run) catch |err| switch (err) {
        // What the database said, in the app's words. The names are the
        // rules written in the migration: the EXCLUDE constraint, the
        // CHECKs, the reference to the room.
        error.ExclusionViolation => return error.SlotTaken,
        error.CheckViolation, error.InvalidDatetimeFormat, error.DatetimeFieldOverflow => return error.InvalidBooking,
        error.ForeignKeyViolation => return error.NoSuchRoom,
        else => return err,
    };
    return (try find(arena, id)).?;
}

/// What stands in the way of a booking of that room and time: for the
/// message after error.SlotTaken.
pub fn overlapping(arena: std.mem.Allocator, room_id: i64, day: []const u8, starts: []const u8, ends: []const u8) ![]model.Booking {
    const sql = "SELECT " ++ columns ++ from ++
        \\WHERE b.room_id = $1 AND b.state IN ('held', 'confirmed')
        \\  AND tsrange(b.day + b.starts, b.day + b.ends) && tsrange($2::date + $3::time, $2::date + $4::time)
        \\ORDER BY b.starts
    ;
    return db.query(model.Booking, arena, sql, .{ room_id, day, starts, ends });
}

/// Confirms a held booking. False when it is not held any more (confirmed
/// already, cancelled, or its hold ran out).
pub fn confirm(arena: std.mem.Allocator, id: i64) !bool {
    const changed = try db.query(i64, arena,
        \\WITH done AS (
        \\    UPDATE bookings SET state = 'confirmed', held_until = NULL
        \\    WHERE id = $1 AND state = 'held' AND held_until >= now()
        \\    RETURNING 1
        \\) SELECT count(*) FROM done
    , .{id});
    return changed == 1;
}

/// Cancels a booking that still takes its room. False when it does not.
pub fn cancel(arena: std.mem.Allocator, id: i64) !bool {
    const changed = try db.query(i64, arena,
        \\WITH done AS (
        \\    UPDATE bookings SET state = 'cancelled', held_until = NULL
        \\    WHERE id = $1 AND state IN ('held', 'confirmed')
        \\    RETURNING 1
        \\) SELECT count(*) FROM done
    , .{id});
    return changed == 1;
}

/// Marks as expired every hold that ran out, and says how many.
pub fn expireStale(arena: std.mem.Allocator) !i64 {
    return db.query(i64, arena,
        \\WITH done AS (
        \\    UPDATE bookings SET state = 'expired' WHERE state = 'held' AND held_until < now() RETURNING 1
        \\) SELECT count(*) FROM done
    , .{});
}

/// The bookings of one account: the ones ahead first (soonest on top), then
/// the ones behind.
pub fn ofUser(arena: std.mem.Allocator, user_id: i64) ![]model.Booking {
    const sql = "SELECT " ++ columns ++ from ++
        \\WHERE b.user_id = $1
        \\ORDER BY (b.day + b.ends < (now() AT TIME ZONE $2)) , abs(extract(epoch FROM (b.day + b.starts) - (now() AT TIME ZONE $2)))
    ;
    return db.query(model.Booking, arena, sql, .{ user_id, timeZone() });
}

/// The bookings of one room from today on, that still take it.
pub fn aheadForRoom(arena: std.mem.Allocator, room_id: i64) ![]model.Booking {
    const sql = "SELECT " ++ columns ++ from ++
        \\WHERE b.room_id = $1 AND b.state IN ('held', 'confirmed') AND b.day >= (now() AT TIME ZONE $2)::date
        \\ORDER BY b.day, b.starts LIMIT 20
    ;
    return db.query(model.Booking, arena, sql, .{ room_id, timeZone() });
}

/// Where the office is, for "today" and "now": the BOOKINGS_TZ variable
/// ("America/Sao_Paulo"), or UTC.
pub fn timeZone() []const u8 {
    return spider.env.getOr("BOOKINGS_TZ", "UTC");
}

/// `day` ("2026-10-12") as the pages talk about it, or today when it is
/// null or not a date. PostgreSQL does the calendar: the weekday, the day
/// before, the day after, and what time it is where the office is.
pub fn dayInfo(arena: std.mem.Allocator, day: ?[]const u8) !model.Day {
    const sql =
        \\SELECT d::text AS day,
        \\       to_char(d, 'FMDay, FMDD FMMonth') AS label,
        \\       (d - 1)::text AS prev, (d + 1)::text AS next,
        \\       d = t AS is_today, d < t AS is_past,
        \\       to_char(n, 'HH24:MI') AS now,
        \\       (extract(hour FROM n) * 60 + extract(minute FROM n))::integer AS now_minutes
        \\FROM (SELECT coalesce($1::date, (now() AT TIME ZONE $2)::date) AS d,
        \\             (now() AT TIME ZONE $2)::date AS t,
        \\             now() AT TIME ZONE $2 AS n) AS clock
    ;
    const asked = db.queryOne(model.Day, arena, sql, .{ day, timeZone() }) catch |err| switch (err) {
        // Not a date: the page shows today.
        error.InvalidDatetimeFormat, error.DatetimeFieldOverflow => null,
        else => return err,
    };
    return asked orelse (try db.queryOne(model.Day, arena, sql, .{ @as(?[]const u8, null), timeZone() })).?;
}
