const std = @import("std");
const spider = @import("spider");
const DriverUsecase = @import("driver_usecase.zig");

const DriverController = @This();

allocator: std.mem.Allocator,
usecase: DriverUsecase,

pub fn init(allocator: std.mem.Allocator, usecase: DriverUsecase) DriverController {
    return .{ .allocator = allocator, .usecase = usecase };
}

pub fn getDrivers(self: DriverController, alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const drivers = try self.usecase.getDrivers();
    return spider.Response.json(alc, drivers);
}
