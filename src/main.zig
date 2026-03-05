const std = @import("std");
const db = @import("db/conn.zig");
const db_pool = @import("db/pool.zig");
const spider = @import("spider");
const DriverController = @import("driver_controller.zig");
const DriverRepository = @import("driver_repository.zig");
const DriverUsecase = @import("driver_usecase.zig");

var driverController: DriverController = undefined;

fn getDrivers(alc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return driverController.getDrivers(alc, req);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    // 1. Connect to the database
    var conn = try db.connect(allocator);
    defer conn.deinit();
    db_pool.init(&conn);

    // 2. Wire up the layers
    const repo = DriverRepository.init(allocator);
    const usecase = DriverUsecase.init(repo);
    driverController = DriverController.init(allocator, usecase);

    // 3. Start the server
    const server = try spider.Spider.init(allocator, io, "127.0.0.1", 8080);
    defer server.deinit();

    server
        .get("/", pingHandler)
        .get("/drivers", getDrivers)
        .listen() catch |err| return err;
}

fn pingHandler(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    return spider.Response.json(alc, .{ .msg = "pong" });
}
