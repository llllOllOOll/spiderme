const std = @import("std");
const spider = @import("spider");
const heartbeat = @import("heartbeat");
const features = @import("features.zig");

/// Every module of the app, in one list: mountModules checks them together
/// and starts them in the order their `requires` give.
const modules = .{heartbeat};

pub fn main() !void {
    try serve();
}

/// Builds the server and listens. main() calls it, and so do the tests in
/// src/app_test.zig.
pub fn serve() !void {
    var server = spider.app(.{});
    defer server.deinit();

    try server
        .use(spider.logger)
        // The modules first: their routes and jobs, their checks before
        // listen() accepts a connection, their boot() before the features'.
        .mountModules(modules)
        .mountFeatures(features)
        .listen(.{});
}

test {
    _ = @import("app_test.zig");
    _ = @import("order_test.zig");
    _ = @import("notify_test.zig");
}
