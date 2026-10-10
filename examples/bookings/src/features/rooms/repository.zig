const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("model.zig");

// `features` is a list in the database (TEXT[]). A row comes back with it
// as one line of text, which is how the pages show it.
const columns = "id, name, capacity, array_to_string(features, ', ') AS features";

/// Every room, by name.
pub fn all(arena: std.mem.Allocator) ![]model.Room {
    return db.query(model.Room, arena, "SELECT " ++ columns ++ " FROM rooms ORDER BY name", .{});
}

/// The rooms that have every one of `wanted` ("projector", "whiteboard").
/// An empty list is every room.
pub fn withFeatures(arena: std.mem.Allocator, wanted: []const []const u8) ![]model.Room {
    // `@>` is "contains": the room's list has all of the wanted ones. The
    // list goes in as ONE parameter, whatever its length.
    const sql = "SELECT " ++ columns ++ " FROM rooms WHERE features @> $1 ORDER BY name";
    return db.query(model.Room, arena, sql, .{db.array([]const u8, wanted)});
}

pub fn find(arena: std.mem.Allocator, id: i64) !?model.Room {
    return db.queryOne(model.Room, arena, "SELECT " ++ columns ++ " FROM rooms WHERE id = $1", .{id});
}

/// Adds a room. error.NameTaken when another room has that name.
pub fn create(arena: std.mem.Allocator, input: model.Input) !model.Room {
    const sql = "INSERT INTO rooms (name, capacity, features) VALUES ($1, $2, $3) RETURNING " ++ columns;
    const row = db.queryOne(model.Room, arena, sql, .{ input.name, input.capacity, db.array([]const u8, input.features) }) catch |err| switch (err) {
        error.UniqueViolation => return error.NameTaken,
        else => return err,
    };
    return row.?;
}
