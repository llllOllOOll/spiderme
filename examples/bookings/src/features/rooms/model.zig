/// A room people book.
pub const Room = struct {
    id: i64,
    name: []const u8,
    /// How many people fit.
    capacity: i32,
    /// What the room has, as one line of text: "projector, whiteboard".
    /// Empty for a room with nothing.
    features: []const u8,
};

/// What the room form sends.
pub const Input = struct {
    name: []const u8,
    capacity: i32,
    features: []const []const u8 = &.{},
};

/// What a room can have. The form shows one checkbox for each.
pub const known_features = [_][]const u8{ "projector", "video call", "whiteboard", "screen", "movable tables" };
