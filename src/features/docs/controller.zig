const std = @import("std");
const spider = @import("spider");

pub fn index(c: *spider.Ctx) !spider.Response {
    return c.view("docs/index", .{}, .{});
}

pub fn quickstart(c: *spider.Ctx) !spider.Response {
    return c.view("docs/quickstart", .{}, .{});
}

pub fn templates(c: *spider.Ctx) !spider.Response {
    return c.view("docs/templates", .{}, .{});
}

pub fn mdTest(c: *spider.Ctx) !spider.Response {
    return c.view("docs/templates", .{ .name = "World" }, .{});
}

pub fn router(c: *spider.Ctx) !spider.Response {
    return c.view("docs/router", .{}, .{});
}

pub fn request(c: *spider.Ctx) !spider.Response {
    return c.view("docs/request", .{}, .{});
}

pub fn response(c: *spider.Ctx) !spider.Response {
    return c.view("docs/response", .{}, .{});
}

pub fn websocket(c: *spider.Ctx) !spider.Response {
    return c.view("docs/websocket", .{}, .{});
}

pub fn postgres(c: *spider.Ctx) !spider.Response {
    return c.view("docs/postgres", .{}, .{});
}

pub fn metrics(c: *spider.Ctx) !spider.Response {
    return c.view("docs/metrics", .{}, .{});
}

pub fn logger(c: *spider.Ctx) !spider.Response {
    return c.view("docs/logger", .{}, .{});
}

pub fn pooling(c: *spider.Ctx) !spider.Response {
    return c.view("docs/pooling", .{}, .{});
}

pub fn static(c: *spider.Ctx) !spider.Response {
    return c.view("docs/static", .{}, .{});
}

pub fn shutdown(c: *spider.Ctx) !spider.Response {
    return c.view("docs/shutdown", .{}, .{});
}

pub fn groups(c: *spider.Ctx) !spider.Response {
    return c.view("docs/groups", .{}, .{});
}

pub fn middleware(c: *spider.Ctx) !spider.Response {
    return c.view("docs/middleware", .{}, .{});
}

pub fn auth(c: *spider.Ctx) !spider.Response {
    return c.view("docs/auth", .{}, .{});
}

pub fn httpClient(c: *spider.Ctx) !spider.Response {
    return c.view("docs/http_client", .{}, .{});
}

pub fn forms(c: *spider.Ctx) !spider.Response {
    return c.view("docs/forms", .{}, .{});
}

pub fn docker(c: *spider.Ctx) !spider.Response {
    return c.view("docs/docker", .{}, .{});
}

pub fn testing(c: *spider.Ctx) !spider.Response {
    return c.view("docs/testing", .{}, .{});
}
