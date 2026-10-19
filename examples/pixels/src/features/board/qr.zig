//! The "Paint with us" QR code: the page's address drawn as an inline SVG.
const std = @import("std");
const spider = @import("spider");

/// An SVG of `text` as a QR code: dark modules on white, with the 4-module
/// quiet zone scanners need.
pub fn svg(arena: std.mem.Allocator, text: []const u8) ![]const u8 {
    var qr = try spider.qrcode.QR.encodeAuto(arena, text, .medium);
    defer qr.deinit();
    const side = qr.size + 8;
    var out: std.Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    try w.print("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 {d} {d}\" shape-rendering=\"crispEdges\" role=\"img\" aria-label=\"QR code of {s}\">", .{ side, side, text });
    try w.print("<rect width=\"{d}\" height=\"{d}\" fill=\"#fff\"/><path fill=\"#1a1c2c\" d=\"", .{ side, side });
    var y: u16 = 0;
    while (y < qr.size) : (y += 1) {
        var x: u16 = 0;
        while (x < qr.size) : (x += 1) {
            if (qr.getModule(x, y)) try w.print("M{d} {d}h1v1h-1z", .{ x + 4, y + 4 });
        }
    }
    try w.writeAll("\"/></svg>");
    return out.written();
}

/// The address this page was opened with: the scheme the proxy reports (or
/// http) and the Host header.
pub fn pageUrl(c: *spider.Ctx) ![]const u8 {
    const scheme = c.header("X-Forwarded-Proto") orelse "http";
    const host = c.header("Host") orelse "localhost";
    return std.fmt.allocPrint(c.arena, "{s}://{s}/", .{ scheme, host });
}

test "the QR code is an SVG with dark modules" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const s = try svg(arena.allocator(), "http://192.168.0.10:3000/");
    try std.testing.expect(std.mem.startsWith(u8, s, "<svg "));
    try std.testing.expect(std.mem.endsWith(u8, s, "</svg>"));
    try std.testing.expect(std.mem.indexOf(u8, s, "h1v1h-1z") != null);
}
