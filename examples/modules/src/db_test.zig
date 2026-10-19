//! The modules' migrations on a real PostgreSQL. Not part of `zig build
//! test`: `./test-db.sh` starts a database that lives for one run.
const std = @import("std");
const spider = @import("spider");
const notify = @import("spider_notify");
const audit = @import("audit/audit.zig");

test "pending migrations keep the server from starting; migrate applies them, modules in start order" {
    const gpa = std.testing.allocator;
    var threaded: std.Io.Threaded = .init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    const a = arena.allocator();

    try spider.pg.init(gpa, io, .{});
    defer spider.pg.deinit();

    var server = spider.app(.{});
    defer server.deinit();
    _ = server.mountModules(.{ notify, audit });

    // A new database: nothing applied yet.
    var before: std.Io.Writer.Allocating = .init(a);
    try server.check(a, io).write(&before.writer);
    try std.testing.expectEqualStrings(
        \\spider: 2 module(s) not ready, refusing to start
        \\  notify: migration notify/0001_init is not applied (run `spider migrate`)
        \\  audit: migration audit/0001_init is not applied (run `spider migrate`)
        \\  audit: migration audit/0002_actor is not applied (run `spider migrate`)
        \\
    , before.written());

    // What `spider migrate` (SPIDER_MIGRATE=1) runs.
    try std.testing.expectEqual(@as(usize, 3), try server.migrate(a));
    try std.testing.expect(server.check(a, io).ok());
    // Nothing left: a second run applies none.
    try std.testing.expectEqual(@as(usize, 0), try server.migrate(a));

    const Row = struct { version: []const u8, checksum: ?[]const u8 };
    const rows = try spider.pg.query(Row, a, "SELECT version, checksum FROM schema_migrations ORDER BY version", .{});
    try std.testing.expectEqual(@as(usize, 3), rows.len);
    try std.testing.expectEqualStrings("audit/0001_init", rows[0].version);
    try std.testing.expectEqualStrings("audit/0002_actor", rows[1].version);
    try std.testing.expectEqualStrings("notify/0001_init", rows[2].version);
    // The SHA-256 of the SQL that ran, in hexadecimal.
    try std.testing.expectEqual(@as(usize, 64), rows[0].checksum.?.len);
}
