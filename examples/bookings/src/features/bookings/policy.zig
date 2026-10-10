//! Who may do what to a booking. The routes name these rules
//! (`.policy = Bookings.route(.confirm)`), and the page of a booking asks
//! the same rule whether to show its buttons (`Bookings.can(c, .cancel, &b)`).
const std = @import("std");
const spider = @import("spider");
const model = @import("model.zig");
const repository = @import("repository.zig");

pub const Bookings = spider.policySet(model.Booking, .{
    .name = "booking",
    .load = load,
    .rules = .{
        .confirm = isOwnerOrAdmin,
        .cancel = isOwnerOrAdmin,
    },
});

/// The booking named by the :id of the path. Null (no such booking, or an
/// id that is not a number) is the 404 page.
pub fn load(c: *spider.Ctx) !?model.Booking {
    const id = std.fmt.parseInt(i64, c.params.get("id") orelse return null, 10) catch return null;
    return repository.find(c.arena, id);
}

/// A booking is changed by the account that made it, or by an admin.
fn isOwnerOrAdmin(c: *spider.Ctx, booking: *const model.Booking) bool {
    if (c.hasRole("admin")) return true;
    const signed_in = signedInId(c) orelse return false;
    return booking.user_id != null and booking.user_id.? == signed_in;
}

/// The id of the account that is signed in: the session carries it as text.
pub fn signedInId(c: *spider.Ctx) ?i64 {
    return std.fmt.parseInt(i64, c.userId() orelse return null, 10) catch null;
}
