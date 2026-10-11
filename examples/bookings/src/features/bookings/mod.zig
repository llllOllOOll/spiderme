const std = @import("std");
pub const spider = @import("spider");
pub const model = @import("model.zig");
pub const repository = @import("repository.zig");
pub const controller = @import("controller.zig");
pub const policy = @import("policy.zig");
pub const notify = @import("notify.zig");
const expiry = @import("jobs.zig");

/// Run by `server.mountFeatures` before the first request: how mail leaves
/// and who else hears about a confirmed booking.
pub const boot = notify.boot;

/// Scheduled by `server.mountFeatures`: every half minute, the holds that
/// ran out are released; once an hour, old bookings are deleted when
/// BOOKINGS_KEEP_DAYS asks for it.
pub const jobs = .{
    spider.every(expiry.every_ms, expiry.expireHolds),
    spider.every(expiry.cleanup_every_ms, expiry.removeOld),
};
pub const routes = @import("routes.zig");

// Makes the tests of this feature's files part of `zig build test`.
test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("routes_test.zig");
}
