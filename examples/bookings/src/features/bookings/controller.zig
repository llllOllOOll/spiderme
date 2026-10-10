const std = @import("std");
const spider = @import("spider");
const model = @import("model.zig");
const repository = @import("repository.zig");
const rooms = @import("../rooms/repository.zig");
const grid = @import("../home/grid.zig");
const day_view = @import("../home/controller.zig");

const policy = @import("policy.zig");

const Response = spider.Response;
/// A booking the route's policy loaded and checked: the visitor may change it.
const Mine = spider.Loaded(model.Booking);

/// What the form holds: what was asked for in the address, or what was
/// typed, kept across a refusal.
const Form = struct {
    room: i64 = 0,
    date: []const u8 = "",
    start: []const u8 = "",
    end: []const u8 = "",
    title: []const u8 = "",
    note: []const u8 = "",
};

/// One message per field; "" is no message.
const Errors = struct {
    time: []const u8 = "",
    title: []const u8 = "",
    note: []const u8 = "",
    /// The room is taken then: the message names the booking in the way.
    conflict: bool = false,

    fn any(self: Errors) bool {
        return self.time.len + self.title.len + self.note.len > 0;
    }
};

/// The form, with the room, the day and the start of the cell that was
/// clicked: /bookings/new?room=2&date=2026-10-12&start=11:00.
pub fn newForm(c: *spider.Ctx) !Response {
    const day = try repository.dayInfo(c.arena, c.queryDecoded("date"));
    const start = c.queryDecoded("start") orelse "09:00";
    const start_slot = grid.slotOf(start) orelse 2;
    return formPage(c, .{
        .room = if (c.query("room")) |text| std.fmt.parseInt(i64, text, 10) catch 0 else 0,
        .date = day.day,
        .start = try grid.timeOf(c.arena, @min(start_slot, grid.slots - 1)),
        // An hour by default, or what is left of the day.
        .end = try grid.timeOf(c.arena, @min(start_slot + 2, grid.slots)),
    }, .{}, .ok);
}

/// Makes the booking. Refused, the form comes back as it was typed, with
/// what is wrong beside the field it is about.
pub fn create(c: *spider.Ctx) !Response {
    const sent = try c.parseForm(Form);
    const form: Form = .{
        .room = sent.room,
        .date = sent.date,
        .start = sent.start,
        .end = sent.end,
        .title = std.mem.trim(u8, sent.title, " \t\r\n"),
        .note = std.mem.trim(u8, sent.note, " \t\r\n"),
    };

    var errors: Errors = .{};
    if (form.title.len == 0) errors.title = "Give the booking a title.";
    if (form.title.len > 80) errors.title = "The title can have up to 80 characters.";
    if (form.note.len > 500) errors.note = "The note can have up to 500 characters.";
    const start = grid.slotOf(form.start);
    const end = grid.slotOf(form.end);
    if (start == null or end == null) {
        errors.time = "Pick a start and an end between 08:00 and 20:00.";
    } else if (end.? <= start.?) {
        errors.time = "The end has to be after the start.";
    }
    if (errors.any()) return formPage(c, form, errors, .unprocessable_entity);

    const made = repository.create(c.arena, .{
        .room_id = form.room,
        .day = form.date,
        .starts = form.start,
        .ends = form.end,
        .title = form.title,
        .note = if (form.note.len > 0) form.note else null,
        .booked_by = c.params.get("_auth_name") orelse "Someone",
        .user_id = viewerId(c),
    }) catch |err| switch (err) {
        error.SlotTaken => {
            errors.conflict = true;
            errors.time = try conflictMessage(c, form);
            return formPage(c, form, errors, .unprocessable_entity);
        },
        error.InvalidBooking => {
            errors.time = "That day and time cannot be booked.";
            return formPage(c, form, errors, .unprocessable_entity);
        },
        error.NoSuchRoom => {
            errors.time = "Pick a room.";
            return formPage(c, form, errors, .unprocessable_entity);
        },
        else => return err,
    };
    day_view.announce(c, made.day);
    return go(c, try std.fmt.allocPrint(c.arena, "/bookings/{d}", .{made.id}));
}

/// "Delta is already booked from 13:00 to 17:00."
fn conflictMessage(c: *spider.Ctx, form: Form) ![]const u8 {
    const taken = try repository.overlapping(c.arena, form.room, form.date, form.start, form.end);
    if (taken.len == 0) return "That time was just taken. Pick another one.";
    return std.fmt.allocPrint(c.arena, "{s} is already {s} from {s} to {s}.", .{
        taken[0].room, if (taken[0].state == .held) "held" else "booked", taken[0].starts, taken[0].ends,
    });
}

const Option = struct { value: []const u8, label: []const u8, selected: bool };
/// A piece of the strip of taken times: where it starts and how long it is.
const Strip = struct { at: usize, len: usize, range: []const u8, title: []const u8, state: []const u8 };

fn formPage(c: *spider.Ctx, form: Form, errors: Errors, status: std.http.Status) !Response {
    const a = c.arena;
    const all_rooms = try rooms.all(a);
    const room_options = try a.alloc(Option, all_rooms.len);
    var room_name: []const u8 = "";
    var room_id = form.room;
    for (all_rooms, room_options, 0..) |room, *option, i| {
        if (room_id == 0 and i == 0) room_id = room.id;
        const selected = room.id == room_id;
        if (selected) room_name = room.name;
        option.* = .{ .value = try std.fmt.allocPrint(a, "{d}", .{room.id}), .label = room.name, .selected = selected };
    }

    const starts = try a.alloc(Option, grid.slots);
    const ends = try a.alloc(Option, grid.slots);
    for (starts, ends, 0..) |*s, *e, slot| {
        const from = try grid.timeOf(a, slot);
        const to = try grid.timeOf(a, slot + 1);
        s.* = .{ .value = from, .label = from, .selected = std.mem.eql(u8, from, form.start) };
        e.* = .{ .value = to, .label = to, .selected = std.mem.eql(u8, to, form.end) };
    }

    // What the room already has that day, drawn beside the form: the rule
    // of the app, visible before and after a refusal.
    const day = try repository.dayInfo(a, form.date);
    var strip: std.ArrayList(Strip) = .empty;
    for (try repository.forDay(a, day.day)) |b| {
        if (b.room_id != room_id) continue;
        const at = grid.slotOf(b.starts) orelse continue;
        const end = grid.slotOf(b.ends) orelse continue;
        try strip.append(a, .{
            .at = at,
            .len = end - at,
            .range = try std.fmt.allocPrint(a, "{s}–{s}", .{ b.starts, b.ends }),
            .title = b.title,
            .state = if (b.state == .held) "Held" else "Booked",
        });
    }
    const asked_at = grid.slotOf(form.start);
    const asked_end = grid.slotOf(form.end);
    const asked_ok = asked_at != null and asked_end != null and asked_end.? > asked_at.?;

    return c.view("bookings/form", .{
        .title = "New booking",
        .nav = "day",
        .is_admin = c.hasRole("admin"),
        .form = form,
        .errors = errors,
        .refused = errors.any(),
        .rooms = room_options,
        .starts = starts,
        .ends = ends,
        .room_name = room_name,
        .day = day,
        .back = try std.fmt.allocPrint(a, "/?date={s}", .{day.day}),
        .strip = strip.items,
        .show_asked = errors.conflict and asked_ok,
        .asked_at = if (asked_ok) asked_at.? else 0,
        .asked_len = if (asked_ok) asked_end.? - asked_at.? else 1,
    }, .{ .status = status });
}

/// One booking: what it is, and for its owner what can be done with it.
pub fn show(c: *spider.Ctx) !Response {
    const booking = try find(c);
    const day = try repository.dayInfo(c.arena, booking.day);
    const viewer = viewerId(c);
    const is_mine = viewer != null and booking.user_id != null and viewer.? == booking.user_id.?;
    const minutes = booking.minutes_left orelse 0;
    return c.view("bookings/show", .{
        .title = booking.title,
        .nav = "day",
        .is_admin = c.hasRole("admin"),
        .booking = booking,
        .day = day,
        .back = try std.fmt.allocPrint(c.arena, "/?date={s}", .{booking.day}),
        .state = if (booking.state == .held and minutes == 0) "expired" else @tagName(booking.state),
        // A hold that ran out is over, even in the half minute before the
        // timer marks it.
        .held = booking.state == .held and minutes > 0,
        .confirmed = booking.state == .confirmed,
        .expired = booking.state == .expired or (booking.state == .held and minutes == 0),
        .cancelled = booking.state == .cancelled,
        .can_act = try policy.Bookings.can(c, .cancel, &booking),
        .mine = is_mine,
        .minutes_left = minutes,
        // The bar under the countdown: tenths of the hold that are left.
        .tenths = @min(10, @max(0, @divFloor(minutes * 10, model.hold_minutes))),
        .rebook = try std.fmt.allocPrint(c.arena, "/bookings/new?room={d}&date={s}&start={s}", .{ booking.room_id, booking.day, booking.starts }),
    }, .{});
}

// The two handlers below are only reached by the owner of the booking or
// an admin: the route's policy loaded it and checked, and hands it over.

/// Keeps a held booking.
pub fn confirm(c: *spider.Ctx, mine_: Mine) !Response {
    const booking = mine_.value;
    _ = try repository.confirm(c.arena, booking.id);
    day_view.announce(c, booking.day);
    return c.redirect(try std.fmt.allocPrint(c.arena, "/bookings/{d}", .{booking.id}));
}

/// Gives a booking up.
pub fn cancel(c: *spider.Ctx, mine_: Mine) !Response {
    const booking = mine_.value;
    _ = try repository.cancel(c.arena, booking.id);
    day_view.announce(c, booking.day);
    return c.redirect(try std.fmt.allocPrint(c.arena, "/bookings/{d}", .{booking.id}));
}

/// The bookings of whoever is signed in.
pub fn mine(c: *spider.Ctx) !Response {
    const viewer = viewerId(c) orelse return error.Unauthorized;
    const all = try repository.ofUser(c.arena, viewer);
    return c.view("bookings/mine", .{
        .title = "My bookings",
        .nav = "mine",
        .is_admin = c.hasRole("admin"),
        .bookings = all,
        .none = all.len == 0,
    }, .{});
}

/// Sends the visitor to `url` after a form. A form htmx posted gets the
/// address in a header instead of a redirect: the browser would follow a
/// redirect by itself and hand htmx the next page as if it were the answer
/// to swap in.
fn go(c: *spider.Ctx, url: []const u8) !Response {
    if (c.isHtmx()) return c.text("", .{ .headers = try c.htmx(.{ .redirect = url }) });
    return c.redirect(url);
}

fn find(c: *spider.Ctx) !model.Booking {
    const id = std.fmt.parseInt(i64, c.params.get("id") orelse "", 10) catch return error.NotFound;
    return try repository.find(c.arena, id) orelse error.NotFound;
}

fn viewerId(c: *spider.Ctx) ?i64 {
    return policy.signedInId(c);
}
