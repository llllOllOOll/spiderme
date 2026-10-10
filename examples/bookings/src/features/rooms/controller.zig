const std = @import("std");
const spider = @import("spider");
const repository = @import("repository.zig");
const model = @import("model.zig");
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

// ── the room form: admins only (see routes.zig) ─────────────────────────

/// What the form sends. A checkbox that is not ticked is not sent, which a
/// form reads as false.
const Form = struct {
    name: []const u8 = "",
    capacity: []const u8 = "",
    projector: bool = false,
    video_call: bool = false,
    whiteboard: bool = false,
    screen: bool = false,
    movable_tables: bool = false,

    fn ticked(self: Form) [model.known_features.len]bool {
        return .{ self.projector, self.video_call, self.whiteboard, self.screen, self.movable_tables };
    }
};

const Errors = struct { name: []const u8 = "", capacity: []const u8 = "" };
const Box = struct { field: []const u8, label: []const u8, on: bool };

pub fn newForm(c: *spider.Ctx) !spider.Response {
    return formPage(c, null, .{}, .{}, .ok);
}

pub fn create(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(Form);
    var errors: Errors = .{};
    const input = try checked(c.arena, form, &errors) orelse return formPage(c, null, form, errors, .unprocessable_entity);
    const room = repository.create(c.arena, input) catch |err| switch (err) {
        error.NameTaken => {
            errors.name = "Another room has that name.";
            return formPage(c, null, form, errors, .unprocessable_entity);
        },
        else => return err,
    };
    return c.redirect(try std.fmt.allocPrint(c.arena, "/rooms/{d}", .{room.id}));
}

pub fn edit(c: *spider.Ctx) !spider.Response {
    const room = try wanted(c);
    var form: Form = .{ .name = room.name, .capacity = try std.fmt.allocPrint(c.arena, "{d}", .{room.capacity}) };
    var it = std.mem.splitSequence(u8, room.features, ", ");
    while (it.next()) |feature| {
        if (std.mem.eql(u8, feature, "projector")) form.projector = true;
        if (std.mem.eql(u8, feature, "video call")) form.video_call = true;
        if (std.mem.eql(u8, feature, "whiteboard")) form.whiteboard = true;
        if (std.mem.eql(u8, feature, "screen")) form.screen = true;
        if (std.mem.eql(u8, feature, "movable tables")) form.movable_tables = true;
    }
    return formPage(c, room, form, .{}, .ok);
}

pub fn update(c: *spider.Ctx) !spider.Response {
    const room = try wanted(c);
    const form = try c.parseForm(Form);
    var errors: Errors = .{};
    const input = try checked(c.arena, form, &errors) orelse return formPage(c, room, form, errors, .unprocessable_entity);
    _ = repository.update(c.arena, room.id, input) catch |err| switch (err) {
        error.NameTaken => {
            errors.name = "Another room has that name.";
            return formPage(c, room, form, errors, .unprocessable_entity);
        },
        else => return err,
    };
    return c.redirect(try std.fmt.allocPrint(c.arena, "/rooms/{d}", .{room.id}));
}

pub fn delete(c: *spider.Ctx) !spider.Response {
    const room = try wanted(c);
    try repository.delete(c.arena, room.id);
    return c.redirect("/rooms");
}

/// The room of the address, or the 404 page.
fn wanted(c: *spider.Ctx) !model.Room {
    const id = std.fmt.parseInt(i64, c.params.get("id") orelse "", 10) catch return error.NotFound;
    return try repository.find(c.arena, id) orelse error.NotFound;
}

/// The form as a room to save, or null with `errors` saying what is wrong.
fn checked(a: std.mem.Allocator, form: Form, errors: *Errors) !?model.Input {
    const name = std.mem.trim(u8, form.name, " \t\r\n");
    if (name.len == 0) errors.name = "Give the room a name.";
    if (name.len > 60) errors.name = "The name can have up to 60 characters.";
    const capacity = std.fmt.parseInt(i32, std.mem.trim(u8, form.capacity, " "), 10) catch 0;
    if (capacity < 1 or capacity > 500) errors.capacity = "Say how many seats the room has: a number from 1 to 500.";
    if (errors.name.len + errors.capacity.len > 0) return null;

    var features: std.ArrayList([]const u8) = .empty;
    for (model.known_features, form.ticked()) |feature, on| {
        if (on) try features.append(a, feature);
    }
    return .{ .name = name, .capacity = capacity, .features = features.items };
}

fn formPage(c: *spider.Ctx, room: ?model.Room, form: Form, errors: Errors, status: std.http.Status) !spider.Response {
    const a = c.arena;
    const fields = [_][]const u8{ "projector", "video_call", "whiteboard", "screen", "movable_tables" };
    const boxes = try a.alloc(Box, fields.len);
    for (boxes, fields, model.known_features, form.ticked()) |*box, field, feature, on| {
        const label = try a.dupe(u8, feature);
        label[0] = std.ascii.toUpper(label[0]);
        box.* = .{ .field = field, .label = label, .on = on };
    }
    return c.view("rooms/form", .{
        .title = if (room) |r| try std.fmt.allocPrint(a, "Edit {s}", .{r.name}) else "New room",
        .nav = "rooms",
        .is_admin = true,
        .editing = room != null,
        .action = if (room) |r| try std.fmt.allocPrint(a, "/rooms/{d}/update", .{r.id}) else "/rooms/create",
        .delete = if (room) |r| try std.fmt.allocPrint(a, "/rooms/{d}/delete", .{r.id}) else "",
        .form = form,
        .errors = errors,
        .boxes = boxes,
    }, .{ .status = status });
}
