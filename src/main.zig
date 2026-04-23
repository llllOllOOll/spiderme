const std = @import("std");
const spg = @import("spider").pg;
const db_migrate = @import("db/migrate.zig");
const spider = @import("spider");
const home = @import("features/home/controller.zig");
const docs = @import("features/docs/controller.zig");
const drivers = @import("features/drivers/controller.zig");

const templates = @import("embedded_templates.zig").EmbeddedTemplates;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    try spider.loadEnv(allocator, ".env");
    try spg.init(allocator, io, .{});
    defer spg.deinit();

    try spider.initWsHub(allocator, io);
    defer spider.deinitWsHub(allocator);

    const server = try spider.Spider.init(allocator, io, "0.0.0.0", 3000, .{
        .templates = templates,
    });
    defer server.deinit();

    server
        .get("/assets/*", spider.static.serve)
        .get("/drivers", drivers.index)
        .get("/", home.index)
        .get("/docs", docs.index)
        .get("/docs/router", docs.router)
        .get("/docs/request", docs.request)
        .get("/docs/response", docs.response)
        .get("/docs/websocket", docs.websocket)
        .get("/docs/postgres", docs.postgres)
        .get("/docs/metrics", docs.metrics)
        .get("/docs/logger", docs.logger)
        .get("/docs/pooling", docs.pooling)
        .get("/docs/static", docs.static)
        .get("/docs/shutdown", docs.shutdown)
        .get("/docs/groups", docs.groups)
        .get("/docs/middleware", docs.middleware)
        .get("/docs/templates", docs.templates)
        .get("/docs/auth", docs.auth)
        .get("/docs/http-client", docs.httpClient)
        .get("/docs/forms", docs.forms)
        .get("/docs/docker", docs.docker)
        .get("/docs/testing", docs.testing)
        .listen() catch |err| return err;
}
