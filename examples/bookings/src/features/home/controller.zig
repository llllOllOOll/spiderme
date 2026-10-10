const std = @import("std");
const spider = @import("spider");
const grid = @import("grid.zig");
const rooms = @import("../rooms/repository.zig");
const bookings = @import("../bookings/repository.zig");

/// The stream a day view listens to: one event, "changed", whenever a
/// booking of that day is made, confirmed, cancelled or expires. It says
/// that something changed, not what: each page then asks for its own grid,
/// because the grid is not the same for everyone (yours are marked as yours).
///
///     /events/2026-10-12
pub fn events(sse: *spider.Sse) !void {
    const day = sse.param("day") orelse return;
    if (!isDay(day)) return;
    try sse.join(try channelOf(sse.arena, day));
    sse.wait();
}

/// Tells every page showing `day` that it changed.
pub fn announce(c: *spider.Ctx, day: []const u8) void {
    const channel = channelOf(c.arena, day) catch return;
    c.sseHub().emitTo(channel, "changed", .{ .day = day });
}

fn channelOf(a: std.mem.Allocator, day: []const u8) ![]const u8 {
    return std.fmt.allocPrint(a, "day:{s}", .{day});
}

/// "2026-10-12": ten characters, digits and two hyphens.
fn isDay(text: []const u8) bool {
    if (text.len != 10) return false;
    for (text, 0..) |ch, i| {
        if (i == 4 or i == 7) {
            if (ch != '-') return false;
        } else if (!std.ascii.isDigit(ch)) return false;
    }
    return true;
}

/// A feature in the filter: its name, whether it is on, and the address
/// that turns it the other way.
const Filter = struct { label: []const u8, on: bool, href: []const u8 };
const Hour = struct { label: []const u8, index: usize };
/// The room names a phone picks from.
const Tab = struct { name: []const u8, href: []const u8, on: bool };

/// The day: every room across, the half hours down, who has what.
///
///     /                           today
///     /?date=2026-10-12           that day
///     /?with=projector,whiteboard only rooms with both
///     /?room=3                    the room a phone shows
pub fn index(c: *spider.Ctx) !spider.Response {
    const a = c.arena;
    const day = try bookings.dayInfo(a, c.queryDecoded("date"));
    const wanted = try wantedFeatures(a, c.queryDecoded("with"));
    const shown: ?i64 = if (c.query("room")) |text| std.fmt.parseInt(i64, text, 10) catch null else null;
    const viewer: ?i64 = if (c.userId()) |id| std.fmt.parseInt(i64, id, 10) catch null else null;

    const all_rooms = try rooms.all(a);
    const matching = if (wanted.len == 0) all_rooms else try rooms.withFeatures(a, wanted);
    const columns = try grid.columns(a, day, matching, try bookings.forDay(a, day.day), viewer, shown);

    // Each chip links to the same day with that feature turned the other way.
    const features = try rooms.allFeatures(a);
    const filters = try a.alloc(Filter, features.len);
    for (features, filters) |feature, *filter| {
        const on = has(wanted, feature);
        filter.* = .{
            .label = try capitalized(a, feature),
            .on = on,
            .href = try address(a, day.day, try toggled(a, wanted, feature, on)),
        };
    }

    const tabs = try a.alloc(Tab, columns.len);
    for (columns, tabs) |column, *tab| tab.* = .{
        .name = column.name,
        .on = column.on.len > 0,
        .href = try std.fmt.allocPrint(a, "{s}&room={d}", .{ try address(a, day.day, wanted), column.id }),
    };

    var hours: [12]Hour = undefined;
    for (&hours, 0..) |*hour, i| hour.* = .{ .label = try grid.timeOf(a, i * 2), .index = i };

    return c.view("home/index", .{
        .title = day.label,
        .nav = "day",
        .is_admin = c.hasRole("admin"),
        .day = day,
        // This same view again: what the page asks for when the day changes.
        .self = if (shown) |room| try std.fmt.allocPrint(a, "{s}&room={d}", .{ try address(a, day.day, wanted), room }) else try address(a, day.day, wanted),
        .prev = try address(a, day.prev, wanted),
        .next = try address(a, day.next, wanted),
        .today = try address(a, null, wanted),
        .filters = filters,
        .filtering = wanted.len > 0,
        .clear = try address(a, day.day, &.{}),
        .wanted = try std.mem.join(a, " and ", wanted),
        .columns = columns,
        .cols = columns.len,
        .tabs = tabs,
        .hours = &hours,
        .has_now = day.is_today and grid.nowStep(day.now_minutes) != null,
        .now_step = grid.nowStep(day.now_minutes) orelse 0,
        .no_rooms = all_rooms.len == 0,
        .no_match = all_rooms.len > 0 and matching.len == 0,
    }, .{});
}

/// "projector,whiteboard" -> the two names, trimmed, lower case, without
/// repeats or empty ones.
fn wantedFeatures(a: std.mem.Allocator, text: ?[]const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, text orelse "", ',');
    while (it.next()) |raw| {
        const name = try std.ascii.allocLowerString(a, std.mem.trim(u8, raw, " "));
        if (name.len == 0 or has(out.items, name)) continue;
        try out.append(a, name);
    }
    return out.items;
}

fn has(list: []const []const u8, name: []const u8) bool {
    for (list) |item| if (std.mem.eql(u8, item, name)) return true;
    return false;
}

/// `wanted` with `feature` taken out (when it is on) or added.
fn toggled(a: std.mem.Allocator, wanted: []const []const u8, feature: []const u8, on: bool) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    for (wanted) |item| {
        if (!std.mem.eql(u8, item, feature)) try out.append(a, item);
    }
    if (!on) try out.append(a, feature);
    return out.items;
}

/// The address of a day with a filter: "/?date=2026-10-12&with=projector".
/// A null date is today, which needs no date in the address.
fn address(a: std.mem.Allocator, date: ?[]const u8, wanted: []const []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.append(a, '/');
    var mark: u8 = '?';
    if (date) |d| {
        try out.print(a, "?date={s}", .{d});
        mark = '&';
    }
    if (wanted.len > 0) {
        try out.print(a, "{c}with=", .{mark});
        for (wanted, 0..) |feature, i| {
            if (i > 0) try out.append(a, ',');
            // A space is the one character of a feature name that an
            // address cannot carry as it is.
            for (feature) |ch| try out.appendSlice(a, if (ch == ' ') "%20" else &.{ch});
        }
    }
    return out.items;
}

fn capitalized(a: std.mem.Allocator, text: []const u8) ![]const u8 {
    const out = try a.dupe(u8, text);
    if (out.len > 0) out[0] = std.ascii.toUpper(out[0]);
    return out;
}

test "address: today needs no date, a filter keeps its features" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expectEqualStrings("/", try address(a, null, &.{}));
    try std.testing.expectEqualStrings("/?date=2026-10-12", try address(a, "2026-10-12", &.{}));
    try std.testing.expectEqualStrings("/?with=projector,video%20call", try address(a, null, &.{ "projector", "video call" }));
    try std.testing.expectEqualStrings("/?date=2026-10-12&with=screen", try address(a, "2026-10-12", &.{"screen"}));
}

test "wantedFeatures and toggled" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const wanted = try wantedFeatures(a, " Projector, whiteboard,,projector ");
    try std.testing.expectEqual(@as(usize, 2), wanted.len);
    try std.testing.expectEqualStrings("projector", wanted[0]);
    try std.testing.expectEqual(@as(usize, 0), (try wantedFeatures(a, null)).len);
    try std.testing.expectEqual(@as(usize, 1), (try toggled(a, wanted, "projector", true)).len);
    try std.testing.expectEqual(@as(usize, 3), (try toggled(a, wanted, "screen", false)).len);
}
