const std = @import("std");
const spider_pg = @import("spider").pg;

pub const Pool = spider_pg.Pool;

pub fn connect(allocator: std.mem.Allocator) !Pool {
    const db_url = "postgres://spider:spider@localhost:5432/spider_db";
    const uri = try std.Uri.parse(db_url);

    const host = if (uri.host) |h| h.percent_encoded else "localhost";
    const user = if (uri.user) |u| u.percent_encoded else "spider";
    const password = if (uri.password) |p| p.percent_encoded else "spider";
    const database = if (uri.path.percent_encoded.len > 1)
        uri.path.percent_encoded[1..]
    else
        "spider_db";

    const config = spider_pg.Config{
        .host = host,
        .port = uri.port orelse 5432,
        .database = database,
        .user = user,
        .password = password,
    };

    return Pool.init(allocator, config);
}
