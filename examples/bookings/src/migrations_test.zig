//! What the migrations in the binary promise, on the test database: each
//! runs once, the server knows which ones the database has, and says what
//! is missing or unknown before it serves.
const std = @import("std");
const spider = @import("spider");
const main = @import("main.zig");
const app_test = @import("app_test.zig");

/// Every file of src/core/db/migrations/, as build.zig embeds them.
const migrations = @import("migrations").all;

test "the migrations run once: a second run applies none" {
    // The running app migrated the test database before it served.
    _ = try app_test.running();
    try std.testing.expectEqual(@as(usize, 0), try main.migrate(std.testing.allocator));
}

test "the check finds every migration applied, under its file name" {
    _ = try app_test.running();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();

    var server = spider.app(.{});
    defer server.deinit();
    const report = server.migrations(migrations).check(arena.allocator(), threaded.io());
    try std.testing.expect(report.ok());
    try std.testing.expectEqual(@as(usize, 0), report.warnings.items.len);

    const Row = struct { version: []const u8, checksum: ?[]const u8 };
    const rows = try spider.pg.query(Row, arena.allocator(), "SELECT version, checksum FROM schema_migrations ORDER BY version", .{});
    try std.testing.expectEqual(migrations.len, rows.len);
    try std.testing.expectEqualStrings("1791667709_create_rooms", rows[0].version);
    try std.testing.expect(rows[0].checksum != null);
}

test "a migration the database does not have keeps the server from starting" {
    _ = try app_test.running();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();

    // A binary built with one more file than the database has seen.
    const newer = migrations ++ [_]spider.Migration{
        .{ .name = "9999999999_add_floor_to_rooms", .sql = "ALTER TABLE rooms ADD COLUMN floor INTEGER;" },
    };
    var server = spider.app(.{});
    defer server.deinit();
    const report = server.migrations(newer).check(arena.allocator(), threaded.io());
    try std.testing.expect(!report.ok());
    try std.testing.expectEqualStrings("app", report.problems.items[0].module);
    try std.testing.expectEqualStrings(
        "migration 9999999999_add_floor_to_rooms is not applied (run `spider migrate`)",
        report.problems.items[0].message,
    );
}

test "a database ahead of the binary is a warning, not a refusal" {
    _ = try app_test.running();
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();

    // The binary of the version before the last migration: a rollback.
    const older = migrations[0 .. migrations.len - 1];
    var server = spider.app(.{});
    defer server.deinit();
    const report = server.migrations(older).check(arena.allocator(), threaded.io());
    try std.testing.expect(report.ok());
    try std.testing.expectEqual(@as(usize, 1), report.warnings.items.len);
    try std.testing.expect(std.mem.indexOf(u8, report.warnings.items[0].message, "1791668114_bookings_belong_to_users") != null);
}
