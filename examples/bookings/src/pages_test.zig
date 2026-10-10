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
    try made.expectStatus(303);
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
    try first.expectStatus(303);

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
    try fits.expectStatus(303);
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

const Room = struct { name: []const u8, capacity: []const u8, projector: []const u8 = "", whiteboard: []const u8 = "" };

test "rooms: only an admin makes, changes and deletes them" {
    const app = try app_test.running();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // Nobody: sent to sign in. Someone who is not an admin: the 403 page.
    var nobody = try app.get("/rooms/new");
    defer nobody.deinit();
    try nobody.expectRedirect("/auth/login");
    var a_buf: [1024]u8 = undefined;
    const ana = app.with(&.{try app_test.signUp(app, &a_buf, "Ana Ribeiro", "ana.rooms@example.com")});
    var refused = try ana.postForm("/rooms/create", Room{ .name = "Grove", .capacity = "5" });
    defer refused.deinit();
    try refused.expectStatus(403);
    try refused.expectContains("Not allowed");
    var list = try ana.get("/rooms");
    defer list.deinit();
    try list.expectNotContains("New room");

    // An account becomes an admin in the database; the next sign-in carries it.
    var d_buf: [1024]u8 = undefined;
    _ = try app_test.signUp(app, &d_buf, "Dana Whitfield", "dana.rooms@example.com");
    try spider.pg.query(void, arena, "UPDATE users SET role = 'admin' WHERE email = $1", .{"dana.rooms@example.com"});
    var signed_in = try app.postForm("/auth/login", .{ .email = "dana.rooms@example.com", .password = "a good password" });
    defer signed_in.deinit();
    var cookie_buf: [1024]u8 = undefined;
    const dana = app.with(&.{try std.fmt.bufPrint(&cookie_buf, "Cookie: session={s}", .{signed_in.cookie("session").?})});

    var admin_list = try dana.get("/rooms");
    defer admin_list.deinit();
    try admin_list.expectContains("New room");

    var blank = try dana.postForm("/rooms/create", Room{ .name = " ", .capacity = "0" });
    defer blank.deinit();
    try blank.expectStatus(422);
    try blank.expectContains("Give the room a name.");
    try blank.expectContains("a number from 1 to 500");
    var taken = try dana.postForm("/rooms/create", Room{ .name = "Atlas", .capacity = "5" });
    defer taken.deinit();
    try taken.expectStatus(422);
    try taken.expectContains("Another room has that name.");

    var made = try dana.postForm("/rooms/create", Room{ .name = "Grove", .capacity = "5", .projector = "true", .whiteboard = "true" });
    defer made.deinit();
    try made.expectStatus(302);
    const location = made.header("Location").?;
    var page = try app.get(location);
    defer page.deinit();
    try page.expectContains("<h1>Grove</h1>");
    try page.expectContains("5 seats");
    try page.expectContains("Projector");
    try page.expectContains("Whiteboard");
    try page.expectNotContains("Screen");

    // The edit form has the room as it is; saving without the projector takes it away.
    var path_buf: [64]u8 = undefined;
    var form = try dana.get(try std.fmt.bufPrint(&path_buf, "{s}/edit", .{location}));
    defer form.deinit();
    try form.expectContains("value=\"Grove\"");
    try form.expectContains("name=\"projector\" value=\"true\" checked");
    try form.expectContains("name=\"screen\" value=\"true\">");
    var update_buf: [64]u8 = undefined;
    var updated = try dana.postForm(try std.fmt.bufPrint(&update_buf, "{s}/update", .{location}), Room{ .name = "Grove", .capacity = "7", .whiteboard = "true" });
    defer updated.deinit();
    try updated.expectRedirect(location);
    var after = try app.get(location);
    defer after.deinit();
    try after.expectContains("7 seats");
    try after.expectNotContains("Projector");

    var delete_buf: [64]u8 = undefined;
    var deleted = try dana.postForm(try std.fmt.bufPrint(&delete_buf, "{s}/delete", .{location}), .{});
    defer deleted.deinit();
    try deleted.expectRedirect("/rooms");
    var gone = try app.get(location);
    defer gone.deinit();
    try gone.expectStatus(404);
    try gone.expectContains("Not found");
}

test "an address that is nothing gets the 404 page" {
    const app = try app_test.running();
    var res = try app.get("/nowhere");
    defer res.deinit();
    try res.expectStatus(404);
    try res.expectContains("There is no page, room or booking at this address.");
    try res.expectContains("Back to the day view");
}

/// Reads from an open stream until `needle` shows up, or fails after the
/// socket's receive timeout.
fn readUntil(reader: *std.Io.Reader, seen: *std.ArrayList(u8), needle: []const u8) !void {
    while (std.mem.indexOf(u8, seen.items, needle) == null) {
        const chunk = reader.peekGreedy(1) catch return error.StreamSaidNothing;
        try seen.appendSlice(std.testing.allocator, chunk);
        reader.toss(chunk.len);
    }
}

test "the day's stream says \"changed\" when a booking of that day is made, and only then" {
    const app = try app_test.running();
    const io = std.testing.io;
    var id_buf: [20]u8 = undefined;
    const cedar = try roomId(&id_buf, "Cedar");
    var buf: [1024]u8 = undefined;
    const ana = app.with(&.{try app_test.signUp(app, &buf, "Ana Ribeiro", "ana.stream3@example.com")});

    // What a day view does: open the stream of its day and keep it open.
    const address = try std.Io.net.IpAddress.parse("127.0.0.1", app.port);
    var stream = try address.connect(io, .{ .mode = .stream });
    defer stream.close(io);
    const timeout = std.posix.timeval{ .sec = 3, .usec = 0 };
    try std.posix.setsockopt(stream.socket.handle, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&timeout));
    var write_buf: [256]u8 = undefined;
    var writer = stream.writer(io, &write_buf);
    try writer.interface.writeAll("GET /events/2032-07-05 HTTP/1.1\r\nHost: 127.0.0.1\r\nAccept: text/event-stream\r\n\r\n");
    try writer.interface.flush();
    var read_buf: [2048]u8 = undefined;
    var reader = stream.reader(io, &read_buf);
    var seen: std.ArrayList(u8) = .empty;
    defer seen.deinit(std.testing.allocator);
    try readUntil(&reader.interface, &seen, "text/event-stream");
    try readUntil(&reader.interface, &seen, "retry:");
    // The stream opens for the client once its handler listens, so what is
    // made from here on is not missed.

    // A booking of another day says nothing here; one of this day does.
    var other = try ana.postForm("/bookings/create", Booking{ .room = cedar, .date = "2032-07-06", .start = "10:00", .end = "11:00", .title = "Another day" });
    defer other.deinit();
    try other.expectStatus(303);
    var made = try ana.postForm("/bookings/create", Booking{ .room = cedar, .date = "2032-07-05", .start = "10:00", .end = "11:00", .title = "Sprint demo" });
    defer made.deinit();
    try made.expectStatus(303);

    try readUntil(&reader.interface, &seen, "event: changed");
    try readUntil(&reader.interface, &seen, "2032-07-05");
    try std.testing.expect(std.mem.indexOf(u8, seen.items, "2032-07-06") == null);

    // And the page that asks again finds it there, pointed out as new.
    var day = try app.get("/?date=2032-07-05");
    defer day.deinit();
    try day.expectContains("ui-cell-changed");
    try day.expectContains("Just booked");
    try day.expectContains("hx-sse:connect=\"/events/2032-07-05\"");
    try day.expectContains("hx-trigger=\"changed from:body, every 60s\"");
}

test "booking: a hold that ran out reads as expired, and offers to book again" {
    const app = try app_test.running();
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    var id_buf: [20]u8 = undefined;
    const cedar = try roomId(&id_buf, "Cedar");
    var buf: [1024]u8 = undefined;
    const ana = app.with(&.{try app_test.signUp(app, &buf, "Ana Ribeiro", "ana.expired@example.com")});

    var made = try ana.postForm("/bookings/create", Booking{ .room = cedar, .date = "2032-07-12", .start = "10:00", .end = "11:00", .title = "Sprint demo" });
    defer made.deinit();
    const location = made.header("Location").?;

    // While it is held, the page asks for itself again every 20 seconds.
    var held = try ana.get(location);
    defer held.deinit();
    try held.expectContains("hx-trigger=\"every 20s\"");
    try held.expectContains("10 min");

    // Eleven minutes pass, and the timer has not come by yet.
    const id = try std.fmt.parseInt(i64, location["/bookings/".len..], 10);
    try spider.pg.query(void, arena_state.allocator(), "UPDATE bookings SET held_until = now() - interval '1 minute' WHERE id = $1", .{id});
    var late = try ana.get(location);
    defer late.deinit();
    try late.expectContains("The hold ran out");
    try late.expectContains("Book it again");
    try late.expectNotContains("Confirm booking");
    try late.expectNotContains("hx-trigger=\"every 20s\"");

    // The timer's work, done here by hand: the booking is marked, and its day is named.
    const days = try features.bookings.repository.expireStale(arena_state.allocator());
    try std.testing.expect(days.len >= 1);
    var after = try app.get(location);
    defer after.deinit();
    try after.expectContains("Expired");
}

/// A server that takes one request and answers 204: where the webhook
/// goes in the test. It keeps what it was sent.
const Hook = struct {
    server: std.Io.net.Server,
    port: u16,
    received: [2048]u8 = undefined,
    len: usize = 0,

    fn listen(io: std.Io) !Hook {
        const address = try std.Io.net.IpAddress.parse("127.0.0.1", 0);
        var server = try address.listen(io, .{ .reuse_address = true });
        return .{ .port = server.socket.address.getPort(), .server = server };
    }

    fn serveOne(self: *Hook) void {
        const io = std.testing.io;
        var stream = self.server.accept(io) catch return;
        defer stream.close(io);
        var read_buf: [2048]u8 = undefined;
        var reader = stream.reader(io, &read_buf);
        // The head, then as many bytes as Content-Length says.
        while (true) {
            const chunk = reader.interface.peekGreedy(1) catch break;
            const n = @min(chunk.len, self.received.len - self.len);
            @memcpy(self.received[self.len..][0..n], chunk[0..n]);
            self.len += n;
            reader.interface.toss(chunk.len);
            const so_far = self.received[0..self.len];
            const head_end = std.mem.indexOf(u8, so_far, "\r\n\r\n") orelse continue;
            const at = std.ascii.findIgnoreCase(so_far, "content-length:") orelse break;
            const line_end = std.mem.indexOfPos(u8, so_far, at, "\r\n") orelse break;
            const length = std.fmt.parseInt(usize, std.mem.trim(u8, so_far[at + "content-length:".len .. line_end], " "), 10) catch break;
            if (self.len >= head_end + 4 + length) break;
        }
        var write_buf: [128]u8 = undefined;
        var writer = stream.writer(io, &write_buf);
        writer.interface.writeAll("HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n") catch {};
        writer.interface.flush() catch {};
    }
};

test "booking: confirming it mails who booked and tells the webhook, once" {
    const app = try app_test.running();
    const notify = features.bookings.notify;
    var id_buf: [20]u8 = undefined;
    const cedar = try roomId(&id_buf, "Cedar");
    var buf: [1024]u8 = undefined;
    const ana = app.with(&.{try app_test.signUp(app, &buf, "Ana Ribeiro", "ana.mail@example.com")});

    // The mail goes to a box in memory, the webhook to a server of the test.
    var outbox: spider.mail.Outbox = .init(std.testing.allocator);
    defer outbox.deinit();
    const mailer_before = notify.mailer;
    const webhook_before = notify.webhook_url;
    defer notify.mailer = mailer_before;
    defer notify.webhook_url = webhook_before;
    notify.mailer = .{ .backend = .{ .memory = &outbox } };

    var hook = try Hook.listen(std.testing.io);
    defer hook.server.deinit(std.testing.io);
    var url_buf: [64]u8 = undefined;
    notify.webhook_url = try std.fmt.bufPrint(&url_buf, "http://127.0.0.1:{d}/hooks/bookings", .{hook.port});
    const listener = try std.Thread.spawn(.{}, Hook.serveOne, .{&hook});

    var made = try ana.postForm("/bookings/create", Booking{ .room = cedar, .date = "2032-07-19", .start = "10:00", .end = "11:00", .title = "Sprint demo" });
    defer made.deinit();
    const location = made.header("Location").?;
    try std.testing.expectEqual(@as(usize, 0), outbox.count()); // held: nothing is said yet

    var confirm_buf: [64]u8 = undefined;
    const confirm = try std.fmt.bufPrint(&confirm_buf, "{s}/confirm", .{location});
    var confirmed = try ana.postForm(confirm, .{});
    defer confirmed.deinit();
    try confirmed.expectRedirect(location);
    listener.join();

    try std.testing.expectEqual(@as(usize, 1), outbox.count());
    const mail = outbox.last().?;
    try std.testing.expectEqualStrings("ana.mail@example.com", mail.to[0].address);
    try std.testing.expectEqualStrings("Ana Ribeiro", mail.to[0].name.?);
    try std.testing.expectEqualStrings("Confirmed: Cedar, Monday, 19 July 10:00", mail.subject);
    try std.testing.expect(std.mem.indexOf(u8, mail.text.?, "Sprint demo") != null);
    try std.testing.expect(std.mem.indexOf(u8, mail.text.?, location) != null);

    const sent = hook.received[0..hook.len];
    try std.testing.expect(std.mem.startsWith(u8, sent, "POST /hooks/bookings HTTP/1.1"));
    try std.testing.expect(std.mem.indexOf(u8, sent, "\"event\":\"booking.confirmed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, sent, "\"room\":\"Cedar\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, sent, "\"day\":\"2032-07-19\"") != null);

    // Confirming again changes nothing and says nothing.
    notify.webhook_url = null;
    var again = try ana.postForm(confirm, .{});
    defer again.deinit();
    try std.testing.expectEqual(@as(usize, 1), outbox.count());
}

test "booking: a webhook that is down does not undo the confirmation" {
    const app = try app_test.running();
    const notify = features.bookings.notify;
    var id_buf: [20]u8 = undefined;
    const cedar = try roomId(&id_buf, "Cedar");
    var buf: [1024]u8 = undefined;
    const ana = app.with(&.{try app_test.signUp(app, &buf, "Ana Ribeiro", "ana.hookdown@example.com")});

    const webhook_before = notify.webhook_url;
    defer notify.webhook_url = webhook_before;
    // A port nothing listens on.
    var probe = try Hook.listen(std.testing.io);
    const dead_port = probe.port;
    probe.server.deinit(std.testing.io);
    var url_buf: [64]u8 = undefined;
    notify.webhook_url = try std.fmt.bufPrint(&url_buf, "http://127.0.0.1:{d}/hooks", .{dead_port});

    var made = try ana.postForm("/bookings/create", Booking{ .room = cedar, .date = "2032-07-26", .start = "10:00", .end = "11:00", .title = "Sprint demo" });
    defer made.deinit();
    const location = made.header("Location").?;
    var confirm_buf: [64]u8 = undefined;
    var confirmed = try ana.postForm(try std.fmt.bufPrint(&confirm_buf, "{s}/confirm", .{location}), .{});
    defer confirmed.deinit();
    try confirmed.expectRedirect(location);
    var page = try ana.get(location);
    defer page.deinit();
    try page.expectContains("Confirmed");
}

test "http client: one client for many calls to the same server" {
    const app = try app_test.running();
    var url_buf: [64]u8 = undefined;
    const base_url = try std.fmt.bufPrint(&url_buf, "http://127.0.0.1:{d}", .{app.port});

    // Made once and kept: its connections are reused from call to call.
    var client = try spider.http_client.Client.init(std.testing.io, std.testing.allocator, .{ .base_url = base_url });
    defer client.deinit();

    var up = try client.get("/up", .{ .timeout_ms = 3000 });
    defer up.deinit();
    try std.testing.expectEqual(std.http.Status.ok, up.status);

    var rooms = try client.get("/rooms", .{ .timeout_ms = 3000 });
    defer rooms.deinit();
    try std.testing.expect(std.mem.indexOf(u8, rooms.body_text, "Atlas") != null);

    // An address that is nothing is an answer too: the call succeeds, the status says 404.
    var missing = try client.get("/nowhere", .{ .timeout_ms = 3000 });
    defer missing.deinit();
    try std.testing.expectEqual(std.http.Status.not_found, missing.status);
}
