//! Uses a part this project did not ask for: build.zig has no `.xlsx = true`.
//! It does not compile, and the build checks that it does not.
const std = @import("std");
const spider = @import("spider");

test "a part that was not asked for is not there" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    _ = try spider.xlsx.Workbook.init(arena.allocator());
}
