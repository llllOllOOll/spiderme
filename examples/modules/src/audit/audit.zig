//! A module with tables: its manifest lists its migrations, `spider migrate`
//! applies them, and the server does not start while one is missing.

const spider = @import("spider");

pub const spider_module = spider.module(.{
    .name = "audit",
    .version = "0.1.0",
    .spider = ">=0.11.0 <0.15.0",
    // In the order they run. Recorded as audit/0001_init, audit/0002_actor.
    .migrations = .{
        .{ .name = "0001_init", .sql = @embedFile("sql/0001_init.sql") },
        .{ .name = "0002_actor", .sql = @embedFile("sql/0002_actor.sql") },
    },
});
