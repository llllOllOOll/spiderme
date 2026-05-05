const std = @import("std");
const db = @import("spider").pg;
const db_migrate = @import("db/migrate.zig");
const spider = @import("spider");
const home = @import("features/home/controller.zig");
const docs = @import("features/docs/controller.zig");
const drivers = @import("features/drivers/controller.zig");

// EMBEDED MODE
pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    try db.init(allocator, io, .{});
    defer db.deinit();

    // try spider.initWsHub(allocator, io);
    // defer spider.deinitWsHub(allocator);

    var server = spider.app();
    defer server.deinit();

    server
        .get("/drivers", drivers.index)
        .get("/", home.index)
        .get("/docs", docs.index)
        .get("/docs/quickstart", docs.quickstart)
        .get("/docs/router", docs.router)
        .get("/docs/request", docs.request)
        .get("/docs/response", docs.response)
        .get("/docs/websocket", docs.websocket)
        .get("/docs/postgresql", docs.postgres)
        .get("/docs/metrics", docs.metrics)
        .get("/docs/logger", docs.logger)
        .get("/docs/pooling", docs.pooling)
        .get("/docs/static", docs.static)
        .get("/docs/shutdown", docs.shutdown)
        .get("/docs/groups", docs.groups)
        .get("/docs/middleware", docs.middleware)
        .get("/docs/templates", docs.templates)
        .get("/docs/md-test", docs.mdTest)
        .get("/docs/auth", docs.auth)
        .get("/docs/http-client", docs.httpClient)
        .get("/docs/forms", docs.forms)
        .get("/docs/docker", docs.docker)
        .get("/docs/testing", docs.testing)
        .onError(errorHandler)
        .listen(.{ .port = 3000, .host = "0.0.0.0" }) catch |err| return err;
}

fn errorHandler(c: *spider.Ctx, err: anyerror) !spider.Response {
    return switch (err) {
        error.TemplateNotFound => c.text(
            try std.fmt.allocPrint(c.arena, "Template not found: {s}", .{c._last_template orelse "unknown"}),
            .{ .status = .not_found },
        ),
        else => c.text(@errorName(err), .{ .status = .internal_server_error }),
    };
}
