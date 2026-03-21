const std = @import("std");
const spg = @import("spider").pg;
const Driver = @import("models/driver.zig").Driver;

const DriverRepository = @This();

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) DriverRepository {
    return .{ .allocator = allocator };
}

pub fn findAll(self: DriverRepository) ![]Driver {
    var result = spg.query("SELECT id, name, team, number FROM drivers ORDER BY number", .{}) catch |err| {
        std.log.err("findAll failed: {}", .{err});
        return err;
    };
    defer result.deinit();

    return result.mapAll(Driver, self.allocator);
}
