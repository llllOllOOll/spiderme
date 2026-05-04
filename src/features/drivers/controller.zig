const std = @import("std");
const spider = @import("spider");
const repository = @import("repository.zig");
const Drivers = @import("model.zig").Drivers;
const db = spider.pg;

// pub fn index(alloc: std.mem.Allocator, _: *spider.Request) !spider.Response {
pub fn index(c: *spider.Ctx) !spider.Response {
    // const drivers = try repository.findAll(alloc);
    const drivers = try db.query(Drivers, c.arena, "SELECT id, name, team, number FROM drivers ORDER BY number", .{});
    return c.json(drivers, .{});
    // jspider.Response.json(alloc, drivers);
}
