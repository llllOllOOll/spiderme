//! Run by build.zig with HEARTBEAT_TOKEN empty.
const std = @import("std");
const spider = @import("spider");
const heartbeat = @import("heartbeat");

test "without HEARTBEAT_TOKEN the server refuses to start, and says why" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();

    var server = spider.app(.{});
    defer server.deinit();
    _ = server.mountModules(.{heartbeat});

    const report = server.check(arena.allocator(), threaded.io());
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    try report.write(&out.writer);
    try std.testing.expectEqualStrings(
        \\spider: 1 module(s) not ready, refusing to start
        \\  heartbeat: HEARTBEAT_TOKEN is required but not set
        \\
    , out.written());

    // listen() runs the same checks, before it binds the port.
    try std.testing.expectError(error.ModulesNotReady, server.listen(.{}));
}
