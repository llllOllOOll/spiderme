const std = @import("std");
const spider = @import("spider");
const tmpl = @embedFile("views/index.html");
const tmpl_docs = @embedFile("views/docs.html");

pub const DocsController = @This();

pub fn docs(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "docs", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn index(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl, "index", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docQuickstart(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_quickstart", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docRouter(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_router", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docWebsocket(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_websocket", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docPostgres(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_postgres", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docMetrics(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_metrics", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docLogger(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_logger", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docPooling(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_pooling", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docStatic(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_static", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docShutdown(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_shutdown", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docGroups(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_groups", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docRequest(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_request", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docResponse(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_response", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docMiddleware(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_middleware", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docTemplates(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_templates", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docDocker(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_docker", .{}, alc);
    return spider.Response.html(alc, html);
}
pub fn docTesting(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_testing", .{}, alc);
    return spider.Response.html(alc, html);
}

pub fn docAuth(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_auth", .{}, alc);
    return spider.Response.html(alc, html);
}

pub fn docHttpClient(alc: std.mem.Allocator, _: *spider.Request) !spider.Response {
    const html = try spider.template.renderBlock(tmpl_docs, "doc_http_client", .{}, alc);
    return spider.Response.html(alc, html);
}
