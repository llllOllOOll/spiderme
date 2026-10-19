//! Run by build.zig with HEARTBEAT_TOKEN set to "short".
const std = @import("std");
const spider = @import("spider");
const heartbeat = @import("heartbeat");

test "a token too short: the module's own check keeps the server from starting" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();

    var server = spider.app(.{});
    defer server.deinit();
    _ = server.mountModules(.{heartbeat});

    const report = server.check(arena.allocator(), threaded.io());
    try std.testing.expect(!report.ok());
    try std.testing.expectEqualStrings("heartbeat", report.problems.items[0].module);
    try std.testing.expectEqualStrings(
        "HEARTBEAT_TOKEN must be at least 16 characters (it has 5)",
        report.problems.items[0].message,
    );
    try std.testing.expectError(error.ModulesNotReady, server.listen(.{}));
}
