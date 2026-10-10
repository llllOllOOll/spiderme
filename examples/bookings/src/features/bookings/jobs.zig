//! What the bookings do on a timer, with nobody asking.
const std = @import("std");
const spider = @import("spider");
const repository = @import("repository.zig");

/// How often the holds are looked at.
pub const every_ms = 30_000;

/// Releases the holds that ran out and tells the pages showing their days.
/// It runs on a thread of its own, outside any request, so it brings its
/// own memory and reports its own errors: there is nobody to return one to.
pub fn expireHolds(hub: *spider.Hub) void {
    var arena_state: std.heap.ArenaAllocator = .init(std.heap.smp_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const days = repository.expireStale(arena) catch |err| {
        std.log.warn("bookings: could not release the holds that ran out: {s}", .{@errorName(err)});
        return;
    };
    for (days) |day| {
        const channel = std.fmt.allocPrint(arena, "day:{s}", .{day}) catch continue;
        hub.emitTo(channel, "changed", .{ .day = day });
    }
    if (days.len > 0) std.log.info("bookings: {d} hold(s) ran out and were released", .{days.len});
}
