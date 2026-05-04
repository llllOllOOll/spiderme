const std = @import("std");
const spider = @import("spider");

pub fn index(c: *spider.Ctx) !spider.Response {
    return c.view("home/index", .{}, .{});
}
