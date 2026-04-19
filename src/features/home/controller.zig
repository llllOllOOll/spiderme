const std = @import("std");
const spider = @import("spider");

pub fn index(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "home/index", .{});
}
