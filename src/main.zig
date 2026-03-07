const std = @import("std");
const db = @import("db/conn.zig");
const db_pool = @import("db/pool.zig");
const db_migrate = @import("db/migrate.zig");
const spider = @import("spider");
const DriverController = @import("driver_controller.zig");
const DriverRepository = @import("driver_repository.zig");
const DriverUsecase = @import("driver_usecase.zig");
const DocsController = @import("docs_controller.zig").DocsController;
const ChatController = @import("chat_controller.zig").ChatController;
var driverController: DriverController = undefined;

fn getDrivers(alc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return driverController.getDrivers(alc, req);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var conn = try db.connect(allocator);
    defer conn.deinit();
    db_pool.init(&conn);
    try db_migrate.run();

    const repo = DriverRepository.init(allocator);
    const usecase = DriverUsecase.init(repo);
    driverController = DriverController.init(allocator, usecase);

    try spider.initWsHub(allocator, io);
    defer spider.deinitWsHub(allocator);

    const server = try spider.Spider.init(allocator, io, "0.0.0.0", 3000);
    defer server.deinit();

    server
        .get("/assets/*", spider.static.serve)
        .get("/drivers", getDrivers)
        .get("/", DocsController.index)
        .get("/ping", pingHandler)
        .get("/chat", ChatController.chatPage)
        .get("/docs/router", DocsController.docRouter)
        .get("/docs/websocket", DocsController.docWebsocket)
        .get("/docs/postgres", DocsController.docPostgres)
        .get("/docs/metrics", DocsController.docMetrics)
        .get("/docs/logger", DocsController.docLogger)
        .get("/docs/pooling", DocsController.docPooling)
        .get("/docs/static", DocsController.docStatic)
        .get("/docs/shutdown", DocsController.docShutdown)
        .get("/docs/groups", DocsController.docGroups)
        .get("/docs/request", DocsController.docRequest)
        .get("/docs/response", DocsController.docResponse)
        .get("/docs/middleware", DocsController.docMiddleware)
        .get("/docs/templates", DocsController.docTemplates)
        .get("/docs/docker", DocsController.docDocker)
        .get("/docs/testing", DocsController.docTesting)
        .listen() catch |err| return err;
}

fn pingHandler(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    return spider.Response.json(alc, .{ .msg = "pong" });
}
