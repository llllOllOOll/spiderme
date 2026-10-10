/// Where a booking is in its life.
pub const State = enum {
    /// Made, and waiting for its owner to confirm it. It holds the room
    /// until `held_until`.
    held,
    /// Kept: the room is taken.
    confirmed,
    /// Given up by its owner. The time is free again.
    cancelled,
    /// Never confirmed. The time is free again.
    expired,
};

/// One booking, as the pages show it.
pub const Booking = struct {
    id: i64,
    room_id: i64,
    /// The room's name.
    room: []const u8,
    /// "2026-10-12"
    day: []const u8,
    /// "09:00"
    starts: []const u8,
    /// "10:30"
    ends: []const u8,
    title: []const u8,
    note: ?[]const u8 = null,
    booked_by: []const u8,
    state: State,
    /// For a held booking: whole minutes until the hold ends, 0 once it
    /// has. null in every other state.
    minutes_left: ?i32 = null,
};

/// What the booking form sends.
pub const Input = struct {
    room_id: i64,
    /// "2026-10-12"
    day: []const u8,
    /// "09:00"
    starts: []const u8,
    /// "10:30"
    ends: []const u8,
    title: []const u8,
    note: ?[]const u8 = null,
    booked_by: []const u8,
};

/// How long a new booking holds its room before it must be confirmed.
pub const hold_minutes = 10;
