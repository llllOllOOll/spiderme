//! The pages, asked for as a browser asks: the running app, a real
//! PostgreSQL (`./test.sh`). Each test books on a day of its own.
const std = @import("std");
const spider = @import("spider");
const features = @import("features");
const app_test = @import("app_test.zig");

/// The id of a sample room, as text for an address or a form.
fn roomId(buf: []u8, name: []const u8) ![]const u8 {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    for (try features.rooms.repository.all(arena.allocator())) |room| {
        if (std.mem.eql(u8, room.name, name)) return std.fmt.bufPrint(buf, "{d}", .{room.id});
    }
    return error.RoomNotFound;
}

const Booking = struct { room: []const u8, date: []const u8, start: []const u8, end: []const u8, title: []const u8, note: []const u8 = "" };

test "the day: every room is a column, and a free half hour is a link to book it" {
    const app = try app_test.running();
    var id_buf: [20]u8 = undefined;
    const birch = try roomId(&id_buf, "Birch");

    var res = try app.get("/?date=2032-05-03");
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectContains("Monday, 3 May");
    for ([_][]const u8{ "Atlas", "Birch", "Cedar", "Delta", "Echo (phone booth)", "Workshop" }) |room| try res.expectContains(room);
    try res.expectContains("12 seats");
    try res.expectContains("1 seat<");

    var link_buf: [128]u8 = undefined;
    try res.expectContains(try std.fmt.bufPrint(&link_buf, "href=\"/bookings/new?room={s}&amp;date=2032-05-03&amp;start=11:00\"", .{birch}));
    try res.expectContains("aria-label=\"Book Birch at 11:00\"");
}

test "the day: a day that is over has nothing to book; not a date shows today" {
    const app = try app_test.running();

    var past = try app.get("/?date=2020-01-06");
    defer past.deinit();
    try past.expectStatus(200);
    try past.expectContains("Monday, 6 January");
    try past.expectNotContains("ui-cell-free");

    var nonsense = try app.get("/?date=tomorrow-ish");
    defer nonsense.deinit();
    try nonsense.expectStatus(200);
    try nonsense.expectContains("Today · open 08:00–20:00");
}

test "the day: the filter keeps only the rooms that have every feature asked for" {
    const app = try app_test.running();

    var res = try app.get("/?date=2032-05-03&with=projector,whiteboard");
    defer res.deinit();
    try res.expectContains("/rooms/");
    try res.expectContains(">Atlas<");
    try res.expectContains(">Workshop<");
    try res.expectNotContains(">Birch<");
    try res.expectContains("Clear filters");

    var none = try app.get("/?date=2032-05-03&with=screen,video%20call");
    defer none.deinit();
    try none.expectStatus(200);
    try none.expectContains("No room has screen and video call");
}

test "booking: needs an account; made, it is held and goes to its page" {
    const app = try app_test.running();
    var id_buf: [20]u8 = undefined;
    const cedar = try roomId(&id_buf, "Cedar");

    // Nobody signed in: sent to sign in, and nothing is booked.
    var anonymous = try app.postForm("/bookings/create", Booking{ .room = cedar, .date = "2032-05-10", .start = "11:00", .end = "12:00", .title = "Sprint demo" });
    defer anonymous.deinit();
    try anonymous.expectRedirect("/auth/login");

    var buf: [1024]u8 = undefined;
    const ana = app.with(&.{try app_test.signUp(app, &buf, "Ana Ribeiro", "ana.pages@example.com")});

    var made = try ana.postForm("/bookings/create", Booking{ .room = cedar, .date = "2032-05-10", .start = "11:00", .end = "12:00", .title = "  Sprint demo  ", .note = "Bring the laptop" });
    defer made.deinit();
    try made.expectStatus(302);
    const location = made.header("Location").?;
    try std.testing.expect(std.mem.startsWith(u8, location, "/bookings/"));

    var page = try ana.get(location);
    defer page.deinit();
    try page.expectStatus(200);
    try page.expectContains("<h1>Sprint demo</h1>");
    try page.expectContains("Held for you");
    try page.expectContains("Confirm booking");
    try page.expectContains("Bring the laptop");

    // On the day it is hers; a visitor sees a hold, and no way to act on it.
    var day = try ana.get("/?date=2032-05-10");
    defer day.deinit();
    try day.expectContains("ui-cell-held ui-is-mine");
    var visitor = try app.get(location);
    defer visitor.deinit();
    try visitor.expectStatus(200);
    try visitor.expectNotContains("Confirm booking");
}

test "booking: a taken time comes back as the form, with the booking in the way and what was typed" {
    const app = try app_test.running();
    var id_buf: [20]u8 = undefined;
    const delta = try roomId(&id_buf, "Delta");
    var a_buf: [1024]u8 = undefined;
    var b_buf: [1024]u8 = undefined;
    const tomas = app.with(&.{try app_test.signUp(app, &a_buf, "Tomás Ferreira", "tomas.pages@example.com")});
    const ana = app.with(&.{try app_test.signUp(app, &b_buf, "Ana Ribeiro", "ana.conflict@example.com")});

    var first = try tomas.postForm("/bookings/create", Booking{ .room = delta, .date = "2032-05-17", .start = "13:00", .end = "17:00", .title = "Customer workshop" });
    defer first.deinit();
    try first.expectStatus(302);

    var refused = try ana.postForm("/bookings/create", Booking{ .room = delta, .date = "2032-05-17", .start = "12:30", .end = "13:30", .title = "Sprint demo", .note = "Quick demo for the team" });
    defer refused.deinit();
    try refused.expectStatus(422);
    try refused.expectContains("Delta is already held from 13:00 to 17:00.");
    try refused.expectContains("This booking was not made.");
    try refused.expectContains("value=\"Sprint demo\"");
    try refused.expectContains("Quick demo for the team");
    try refused.expectContains("ui-mini-asked");
    try refused.expectContains("13:00–17:00 · Held");

    // Right before it is fine.
    var fits = try ana.postForm("/bookings/create", Booking{ .room = delta, .date = "2032-05-17", .start = "12:00", .end = "13:00", .title = "Sprint demo" });
    defer fits.deinit();
    try fits.expectStatus(302);
}

test "booking: what is wrong with the form is said beside its field" {
    const app = try app_test.running();
    var id_buf: [20]u8 = undefined;
    const cedar = try roomId(&id_buf, "Cedar");
    var buf: [1024]u8 = undefined;
    const ana = app.with(&.{try app_test.signUp(app, &buf, "Ana Ribeiro", "ana.invalid@example.com")});

    var untitled = try ana.postForm("/bookings/create", Booking{ .room = cedar, .date = "2032-05-24", .start = "10:00", .end = "11:00", .title = "   " });
    defer untitled.deinit();
    try untitled.expectStatus(422);
    try untitled.expectContains("Give the booking a title.");

    var backwards = try ana.postForm("/bookings/create", Booking{ .room = cedar, .date = "2032-05-24", .start = "11:00", .end = "10:00", .title = "Sprint demo" });
    defer backwards.deinit();
    try backwards.expectStatus(422);
    try backwards.expectContains("The end has to be after the start.");

    var no_day = try ana.postForm("/bookings/create", Booking{ .room = cedar, .date = "2032-02-30", .start = "10:00", .end = "11:00", .title = "Sprint demo" });
    defer no_day.deinit();
    try no_day.expectStatus(422);
    try no_day.expectContains("That day and time cannot be booked.");
}

test "booking: a form htmx posted is answered for htmx" {
    const app = try app_test.running();
    var id_buf: [20]u8 = undefined;
    const cedar = try roomId(&id_buf, "Cedar");
    var buf: [1024]u8 = undefined;
    const cookie = try app_test.signUp(app, &buf, "Ana Ribeiro", "ana.htmx@example.com");
    const ana = app.with(&.{ cookie, "HX-Request: true" });

    // Made: the next address in a header, since the browser would follow a
    // redirect by itself.
    var made = try ana.postForm("/bookings/create", Booking{ .room = cedar, .date = "2032-05-31", .start = "10:00", .end = "11:00", .title = "Sprint demo" });
    defer made.deinit();
    try made.expectStatus(200);
    try std.testing.expect(std.mem.startsWith(u8, made.header("HX-Redirect").?, "/bookings/"));

    // Refused: the same 422 and the same page; htmx takes the form out of it.
    var refused = try ana.postForm("/bookings/create", Booking{ .room = cedar, .date = "2032-05-31", .start = "10:30", .end = "11:30", .title = "Another" });
    defer refused.deinit();
    try refused.expectStatus(422);
    try refused.expectContains("id=\"booking\"");
    try refused.expectContains("Cedar is already held from 10:00 to 11:00.");
}

test "booking: only its owner confirms or cancels it" {
    const app = try app_test.running();
    var id_buf: [20]u8 = undefined;
    const cedar = try roomId(&id_buf, "Cedar");
    var a_buf: [1024]u8 = undefined;
    var b_buf: [1024]u8 = undefined;
    const ana = app.with(&.{try app_test.signUp(app, &a_buf, "Ana Ribeiro", "ana.owner@example.com")});
    const marcus = app.with(&.{try app_test.signUp(app, &b_buf, "Marcus Lee", "marcus.owner@example.com")});

    var made = try ana.postForm("/bookings/create", Booking{ .room = cedar, .date = "2032-06-07", .start = "10:00", .end = "11:00", .title = "Sprint demo" });
    defer made.deinit();
    const location = made.header("Location").?;
    var confirm_buf: [64]u8 = undefined;
    var cancel_buf: [64]u8 = undefined;
    const confirm = try std.fmt.bufPrint(&confirm_buf, "{s}/confirm", .{location});
    const cancel = try std.fmt.bufPrint(&cancel_buf, "{s}/cancel", .{location});

    var not_his = try marcus.postForm(confirm, .{});
    defer not_his.deinit();
    try not_his.expectStatus(403);
    var nobody = try app.postForm(cancel, .{});
    defer nobody.deinit();
    try nobody.expectRedirect("/auth/login");

    var confirmed = try ana.postForm(confirm, .{});
    defer confirmed.deinit();
    try confirmed.expectRedirect(location);
    var page = try ana.get(location);
    defer page.deinit();
    try page.expectContains("Confirmed");
    try page.expectNotContains("Held for you");

    var cancelled = try ana.postForm(cancel, .{});
    defer cancelled.deinit();
    try cancelled.expectRedirect(location);
    var after = try app.get(location);
    defer after.deinit();
    try after.expectContains("This booking was cancelled.");

    // Her list has it, and the day has the time back.
    var mine = try ana.get("/bookings");
    defer mine.deinit();
    try mine.expectContains("Sprint demo");
    var day = try app.get("/?date=2032-06-07");
    defer day.deinit();
    try day.expectNotContains("Sprint demo");
}

test "rooms: the list, one room, and a room that does not exist" {
    const app = try app_test.running();
    var id_buf: [20]u8 = undefined;
    const atlas = try roomId(&id_buf, "Atlas");

    var list = try app.get("/rooms");
    defer list.deinit();
    try list.expectStatus(200);
    try list.expectContains("Workshop");
    try list.expectContains("Movable tables");
    try list.expectContains("No equipment");

    var path_buf: [32]u8 = undefined;
    var one = try app.get(try std.fmt.bufPrint(&path_buf, "/rooms/{s}", .{atlas}));
    defer one.deinit();
    try one.expectStatus(200);
    try one.expectContains("<h1>Atlas</h1>");
    try one.expectContains("Video call");

    var missing = try app.get("/rooms/999999");
    defer missing.deinit();
    try missing.expectStatus(404);
    var not_a_number = try app.get("/bookings/abc");
    defer not_a_number.deinit();
    try not_a_number.expectStatus(404);
}
