//! notify, the official notifications module, mounted the way an app
//! mounts it. Its tables live in PostgreSQL: without a database the server
//! says so before it listens.
const std = @import("std");
const spider = @import("spider");
const notify = @import("spider_notify");
const heartbeat = @import("heartbeat");

test "notify's manifest: its name, and the migrations it brings" {
    const manifest = notify.spider_module.manifest;
    try std.testing.expectEqualStrings("notify", manifest.name);
    try std.testing.expectEqualStrings("0001_init", manifest.migrations[0].name);
}

test "notify without a database: the report says what to do" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();

    // No spider.pg.init(...) in this test.
    var server = spider.app(.{});
    defer server.deinit();
    _ = server.mountModules(.{ notify, heartbeat });

    const report = server.check(arena.allocator(), threaded.io());
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    try report.write(&out.writer);
    try std.testing.expectEqualStrings(
        \\spider: 1 module(s) not ready, refusing to start
        \\  notify: ships database migrations, but the database is not open: call spider.pg.init(...) before listen()
        \\
    , out.written());
}
