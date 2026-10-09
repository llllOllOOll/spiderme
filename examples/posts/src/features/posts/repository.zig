const std = @import("std");
const spider = @import("spider");
const db = spider.sqlite;
const model = @import("model.zig");

const columns =
    "id, title, body, author, COALESCE(user_id, 0) AS user_id, " ++
    "CAST(strftime('%s', 'now') - strftime('%s', inserted_at) AS INTEGER) AS age";

/// Every post, newest first.
pub fn list(arena: std.mem.Allocator) ![]model.Post {
    const sql = "SELECT " ++ columns ++ " FROM posts ORDER BY inserted_at DESC, id DESC";
    return db.query(model.Post, arena, sql, .{});
}

/// Posts whose title or body contains `term`, newest first.
pub fn search(arena: std.mem.Allocator, term: []const u8) ![]model.Post {
    const sql = "SELECT " ++ columns ++ " FROM posts " ++
        "WHERE instr(lower(title), lower(?1)) > 0 OR instr(lower(body), lower(?1)) > 0 " ++
        "ORDER BY inserted_at DESC, id DESC";
    return db.query(model.Post, arena, sql, .{term});
}

pub fn find(arena: std.mem.Allocator, id: i64) !?model.Post {
    const sql = "SELECT " ++ columns ++ " FROM posts WHERE id = ?1";
    return db.queryOne(model.Post, arena, sql, .{id});
}

/// Saves a new post and gives back its id. `user_id` is the account that
/// wrote it, or null for a post that belongs to no account.
pub fn create(arena: std.mem.Allocator, input: model.Input, user_id: ?i64) !i64 {
    const Row = struct { id: i64 };
    const sql = "INSERT INTO posts (title, body, author, user_id) VALUES (?1, ?2, ?3, ?4) RETURNING id";
    const row = try db.queryOne(Row, arena, sql, .{ input.title, input.body, input.author, user_id });
    return (row orelse return error.InsertFailed).id;
}

pub fn update(arena: std.mem.Allocator, id: i64, input: model.Input) !void {
    const sql = "UPDATE posts SET title = ?1, body = ?2, author = ?3 WHERE id = ?4";
    _ = try db.query(void, arena, sql, .{ input.title, input.body, input.author, id });
}

pub fn delete(arena: std.mem.Allocator, id: i64) !void {
    _ = try db.query(void, arena, "DELETE FROM posts WHERE id = ?1", .{id});
}
