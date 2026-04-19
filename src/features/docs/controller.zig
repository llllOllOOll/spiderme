const std = @import("std");
const spider = @import("spider");

pub fn index(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/quickstart", .{});
}

pub fn router(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/router", .{});
}

pub fn request(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/request", .{});
}

pub fn response(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/response", .{});
}

pub fn websocket(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/websocket", .{});
}

pub fn postgres(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/postgres", .{});
}

pub fn metrics(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/metrics", .{});
}

pub fn logger(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/logger", .{});
}

pub fn pooling(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/pooling", .{});
}

pub fn static(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/static", .{});
}

pub fn shutdown(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/shutdown", .{});
}

pub fn groups(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/groups", .{});
}

pub fn middleware(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/middleware", .{});
}

pub fn templates(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/templates", .{});
}

pub fn auth(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/auth", .{});
}

pub fn httpClient(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/http_client", .{});
}

pub fn forms(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/forms", .{});
}

pub fn docker(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/docker", .{});
}

pub fn testing(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    return spider.chuckBerry(alloc, req, "docs/testing", .{});
}
