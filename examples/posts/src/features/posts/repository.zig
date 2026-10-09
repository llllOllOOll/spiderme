const std = @import("std");
const spider = @import("spider");
const db = spider.sqlite;
const model = @import("model.zig");

pub fn findAll(alloc: std.mem.Allocator) ![]model.Posts {
    const sql = "SELECT id, name FROM posts ORDER BY id DESC";
    return try db.query(model.Posts, alloc, sql, .{});
}
pub fn findById(alloc: std.mem.Allocator, id: i64) !?model.Posts {
    const sql = "SELECT id, name FROM posts WHERE id = ?1 LIMIT 1";
    return try db.queryOne(model.Posts, alloc, sql, .{id});
}
pub fn create(alloc: std.mem.Allocator, input: model.CreateInput) !?model.Posts {
    const sql = "INSERT INTO posts (name) VALUES (?1) RETURNING id, name";
    return try db.queryOne(model.Posts, alloc, sql, .{input.name});
}
pub fn update(alloc: std.mem.Allocator, id: i64, updates: model.UpdateInput) !?model.Posts {
    const current = try findById(alloc, id) orelse return null;
    const new_name = updates.name orelse current.name;
    const sql = "UPDATE posts SET name = ?1 WHERE id = ?2 RETURNING id, name";
    return try db.queryOne(model.Posts, alloc, sql, .{ new_name, id });
}
pub fn delete(alloc: std.mem.Allocator, id: i64) !void {
    const sql = "DELETE FROM posts WHERE id = ?1";
    _ = try db.query(void, alloc, sql, .{id});
}
