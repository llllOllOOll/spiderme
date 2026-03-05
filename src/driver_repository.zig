const std = @import("std");
const spg = @import("spider").pg;
const db_pool = @import("db/pool.zig");
const Driver = @import("models/driver.zig").Driver;

const DriverRepository = @This();

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) DriverRepository {
    return .{ .allocator = allocator };
}

pub fn findAll(self: DriverRepository) ![]Driver {
    const pool = db_pool.get();
    const conn = try pool.acquire();
    defer pool.release(conn);

    var result = spg.query(conn, "SELECT id, name, team, number FROM drivers ORDER BY number") catch |err| {
        std.log.err("findAll failed: {}", .{err});
        return err;
    };
    defer result.deinit();

    const count = result.rows();
    if (count == 0) return &[_]Driver{};

    const drivers = try self.allocator.alloc(Driver, count);
    errdefer self.allocator.free(drivers);

    for (drivers, 0..) |*driver, i| {
        driver.* = .{
            .id = try std.fmt.parseInt(i32, result.getValue(i, 0), 10),
            .name = try self.allocator.dupe(u8, result.getValue(i, 1)),
            .team = try self.allocator.dupe(u8, result.getValue(i, 2)),
            .number = try std.fmt.parseInt(i32, result.getValue(i, 3), 10),
        };
    }

    return drivers;
}
