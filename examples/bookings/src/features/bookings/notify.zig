//! What goes out of the app when a booking is confirmed: a mail to who
//! booked, and a call to an address of the office's choosing. Neither is
//! allowed to undo the confirmation: a mail that cannot be sent is a line
//! in the log, not an error page.
const std = @import("std");
const spider = @import("spider");
const model = @import("model.zig");

/// How the mail leaves. Until `boot` runs it only writes to the log.
pub var mailer: spider.mail.Mailer = .{ .backend = .{ .log = .{} } };
/// The address told about a confirmed booking, or null to tell nobody.
pub var webhook_url: ?[]const u8 = null;

const default_sender: spider.mail.Mailbox = .{ .name = "Bookings", .address = "bookings@example.org" };

/// Read once, when the server starts (`server.mountFeatures` calls it):
/// MAIL_TRANSPORT and its key decide how mail is sent (the log, when
/// nothing is set), BOOKINGS_WEBHOOK_URL who else is told.
pub fn boot(_: spider.Boot) !void {
    mailer = try spider.mail.Mailer.fromEnv();
    webhook_url = spider.env.get("BOOKINGS_WEBHOOK_URL");
}

/// Who a mail about a booking goes to.
pub const Owner = struct { name: []const u8, email: []const u8 };

/// Tells the owner, and the webhook, that `booking` is confirmed.
pub fn confirmed(c: *spider.Ctx, booking: model.Booking, owner: ?Owner, day_label: []const u8) void {
    if (owner) |to| mail(c, booking, to, day_label) catch |err| {
        std.log.warn("bookings: the confirmation of booking {d} was not mailed: {s}", .{ booking.id, @errorName(err) });
    };
    if (webhook_url) |url| call(c, url, booking) catch |err| {
        std.log.warn("bookings: the webhook was not told about booking {d}: {s}", .{ booking.id, @errorName(err) });
    };
}

fn mail(c: *spider.Ctx, booking: model.Booking, to: Owner, day_label: []const u8) !void {
    const a = c.arena;
    const link = try std.fmt.allocPrint(a, "{s}/bookings/{d}", .{ spider.env.getOr("BOOKINGS_URL", "http://localhost:3000"), booking.id });
    const recipients = try a.alloc(spider.mail.Mailbox, 1);
    recipients[0] = .{ .name = to.name, .address = to.email };
    _ = try mailer.send(c, .{
        .from = mailer.from orelse default_sender,
        .to = recipients,
        .subject = try std.fmt.allocPrint(a, "Confirmed: {s}, {s} {s}", .{ booking.room, day_label, booking.starts }),
        .text = try std.fmt.allocPrint(a,
            \\Your booking is confirmed.
            \\
            \\{s}
            \\{s}
            \\{s}, {s} to {s}
            \\
            \\See it or cancel it: {s}
            \\
        , .{ booking.title, booking.room, day_label, booking.starts, booking.ends, link }),
    });
}

/// What the webhook receives, as JSON.
const Event = struct {
    event: []const u8 = "booking.confirmed",
    id: i64,
    room: []const u8,
    day: []const u8,
    starts: []const u8,
    ends: []const u8,
    title: []const u8,
    booked_by: []const u8,
};

fn call(c: *spider.Ctx, url: []const u8, booking: model.Booking) !void {
    const body = try std.json.Stringify.valueAlloc(c.arena, Event{
        .id = booking.id,
        .room = booking.room,
        .day = booking.day,
        .starts = booking.starts,
        .ends = booking.ends,
        .title = booking.title,
        .booked_by = booking.booked_by,
    }, .{});
    // Three seconds, then the request gives up: someone else's server
    // being slow is not a reason to keep this visitor waiting.
    var res = try spider.http_client.post(c.io(), c.arena, url, .{
        .body = .{ .json = body },
        .timeout_ms = 3000,
    });
    defer res.deinit();
    if (@intFromEnum(res.status) >= 300) return error.WebhookRefused;
}
