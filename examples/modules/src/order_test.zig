//! What mountModules does with several modules: the order they start in,
//! and what the report says before the server listens.
const std = @import("std");
const spider = @import("spider");
const heartbeat = @import("heartbeat");

/// The names of the modules whose check ran, in that order.
var checked: [4][]const u8 = undefined;
var checked_len: usize = 0;

fn record(name: []const u8) void {
    checked[checked_len] = name;
    checked_len += 1;
}

const audit = struct {
    pub const spider_module = spider.module(.{
        .name = "audit",
        .version = "1.0.0",
        .spider = ">=0.11.0 <0.12.0",
    });

    pub fn check(_: *spider.Check) !void {
        record("audit");
    }
};

const billing = struct {
    pub const spider_module = spider.module(.{
        .name = "billing",
        .version = "1.0.0",
        .spider = ">=0.11.0 <0.12.0",
        // audit starts before billing, whatever the order they are mounted in.
        .requires = .{"audit"},
    });

    pub fn check(_: *spider.Check) !void {
        record("billing");
    }
};

const mailer = struct {
    pub const spider_module = spider.module(.{
        .name = "mailer",
        .version = "1.0.0",
        .spider = ">=0.11.0 <0.12.0",
        .env = .{ .required = .{"EXAMPLE_SMTP_URL"} },
    });
};

test "modules start after the modules they require" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();

    var server = spider.app(.{});
    defer server.deinit();
    _ = server.mountModules(.{ billing, audit });

    checked_len = 0;
    const report = server.check(arena.allocator(), threaded.io());
    try std.testing.expect(report.ok());
    try std.testing.expectEqual(@as(usize, 2), report.checked);
    try std.testing.expectEqualStrings("audit", checked[0]);
    try std.testing.expectEqualStrings("billing", checked[1]);
}

test "a required variable that is not set keeps the server from starting" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();

    var server = spider.app(.{});
    defer server.deinit();
    _ = server.mountModules(.{ heartbeat, mailer });

    const report = server.check(arena.allocator(), threaded.io());
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    try report.write(&out.writer);
    try std.testing.expectEqualStrings(
        \\spider: 1 module(s) not ready, refusing to start
        \\  mailer: EXAMPLE_SMTP_URL is required but not set
        \\
    , out.written());
}

test "every module goes in one mountModules call" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();

    var server = spider.app(.{});
    defer server.deinit();
    _ = server.mountModules(.{audit}).mountModules(.{heartbeat});

    const report = server.check(arena.allocator(), threaded.io());
    try std.testing.expect(!report.ok());
    try std.testing.expectEqualStrings("spider", report.problems.items[0].module);
}

test "spider.version is the Spider the app is built with" {
    try std.testing.expect(spider.version.order(try std.SemanticVersion.parse("0.11.0")) != .lt);
}
