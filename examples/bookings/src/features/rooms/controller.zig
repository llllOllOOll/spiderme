const std = @import("std");
const spider = @import("spider");
const repository = @import("repository.zig");
const bookings = @import("../bookings/repository.zig");

const Card = struct { id: i64, name: []const u8, seats: []const u8, features: []const []const u8, bare: bool };

/// Every room, with what it has.
pub fn index(c: *spider.Ctx) !spider.Response {
    const a = c.arena;
    const rooms = try repository.all(a);
    const cards = try a.alloc(Card, rooms.len);
    for (rooms, cards) |room, *card| {
        const list = try featureList(a, room.features);
        card.* = .{ .id = room.id, .name = room.name, .seats = try seats(a, room.capacity), .features = list, .bare = list.len == 0 };
    }
    return c.view("rooms/index", .{
        .title = "Rooms",
        .nav = "rooms",
        .is_admin = c.hasRole("admin"),
        .rooms = cards,
        .none = cards.len == 0,
    }, .{});
}

/// One room and what is booked in it from today on.
pub fn show(c: *spider.Ctx) !spider.Response {
    const a = c.arena;
    const id = std.fmt.parseInt(i64, c.params.get("id") orelse "", 10) catch return error.NotFound;
    const room = try repository.find(a, id) orelse return error.NotFound;
    const ahead = try bookings.aheadForRoom(a, room.id);
    const today = try bookings.dayInfo(a, null);
    const list = try featureList(a, room.features);
    return c.view("rooms/show", .{
        .title = room.name,
        .nav = "rooms",
        .is_admin = c.hasRole("admin"),
        .room = room,
        .seats = try seats(a, room.capacity),
        .features = list,
        .bare = list.len == 0,
        .bookings = ahead,
        .none = ahead.len == 0,
        .book = try std.fmt.allocPrint(a, "/bookings/new?room={d}&date={s}", .{ room.id, today.day }),
    }, .{});
}

fn seats(a: std.mem.Allocator, capacity: i32) ![]const u8 {
    return std.fmt.allocPrint(a, "{d} {s}", .{ capacity, if (capacity == 1) "seat" else "seats" });
}

/// "projector, whiteboard" -> the two names, capitalized for the page.
fn featureList(a: std.mem.Allocator, text: []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitSequence(u8, text, ", ");
    while (it.next()) |name| {
        if (name.len == 0) continue;
        const shown = try a.dupe(u8, name);
        shown[0] = std.ascii.toUpper(shown[0]);
        try out.append(a, shown);
    }
    return out.items;
}
