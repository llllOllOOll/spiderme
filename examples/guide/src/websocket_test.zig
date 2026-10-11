//! content/docs/websocket.md: a socket both sides write to.
const std = @import("std");
const spider = @import("spider");
const run = @import("server.zig").run;

/// The little of a WebSocket client a test needs: the handshake, a text
/// message out, a text message in. A browser does all of it by itself.
const Client = struct {
    stream: std.Io.net.Stream,
    reader: std.Io.net.Stream.Reader,
    writer: std.Io.net.Stream.Writer,
    read_buf: [2048]u8 = undefined,
    write_buf: [512]u8 = undefined,

    fn open(self: *Client, app: spider.testing.App, path: []const u8) !void {
        const io = std.testing.io;
        const address = try std.Io.net.IpAddress.parse("127.0.0.1", app.port);
        self.stream = try address.connect(io, .{ .mode = .stream });
        const timeout = std.posix.timeval{ .sec = 3, .usec = 0 };
        try std.posix.setsockopt(self.stream.socket.handle, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&timeout));
        self.reader = self.stream.reader(io, &self.read_buf);
        self.writer = self.stream.writer(io, &self.write_buf);

        try self.writer.interface.print("GET {s} HTTP/1.1\r\nHost: 127.0.0.1\r\n" ++
            "Upgrade: websocket\r\nConnection: Upgrade\r\n" ++
            "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n", .{path});
        try self.writer.interface.flush();

        // "HTTP/1.1 101 Switching Protocols", then headers up to a blank line.
        const status = try self.reader.interface.takeDelimiterInclusive('\n');
        try std.testing.expect(std.mem.indexOf(u8, status, " 101 ") != null);
        while ((try self.reader.interface.takeDelimiterInclusive('\n')).len > 2) {}
    }

    fn say(self: *Client, text: []const u8) !void {
        // One text frame. A client masks what it sends; a mask of zeros
        // leaves the bytes as they are.
        try self.writer.interface.writeAll(&.{ 0x81, 0x80 | @as(u8, @intCast(text.len)), 0, 0, 0, 0 });
        try self.writer.interface.writeAll(text);
        try self.writer.interface.flush();
    }

    fn hear(self: *Client) ![]const u8 {
        const head = try self.reader.interface.take(2);
        try std.testing.expectEqual(@as(u8, 0x81), head[0]);
        return self.reader.interface.take(head[1]);
    }

    fn close(self: *Client) void {
        self.stream.close(std.testing.io);
    }
};

test "websocket: what one says, everyone in the same room hears, and nobody else" {
    const app = try spider.testing.start(run);

    var ana: Client = undefined;
    try ana.open(app, "/rooms/zig/chat");
    defer ana.close();
    var bo: Client = undefined;
    try bo.open(app, "/rooms/zig/chat");
    defer bo.close();
    var cy: Client = undefined;
    try cy.open(app, "/rooms/rust/chat");
    defer cy.close();

    // Each one is greeted when its handler starts.
    try std.testing.expectEqualStrings("welcome", try ana.hear());
    try std.testing.expectEqualStrings("welcome", try bo.hear());
    try std.testing.expectEqualStrings("welcome", try cy.hear());

    try ana.say("hello, zig");
    try std.testing.expectEqualStrings("hello, zig", try bo.hear());
    // The one who spoke hears it too.
    try std.testing.expectEqualStrings("hello, zig", try ana.hear());

    // The other room heard nothing: its next message is its own.
    try cy.say("hello, rust");
    try std.testing.expectEqualStrings("hello, rust", try cy.hear());
}

const upgrade = "Upgrade: websocket";
const connection = "Connection: Upgrade";
const key = "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==";
const version = "Sec-WebSocket-Version: 13";

test "websocket: a route's access is checked before the socket opens" {
    const app = try spider.testing.start(run);
    var res = try app.with(&.{ upgrade, connection, key, version }).get("/staff/feed");
    defer res.deinit();
    try res.expectStatus(401);
}

test "websocket: a page on another site cannot open one" {
    const app = try spider.testing.start(run);
    var res = try app.with(&.{ upgrade, connection, key, version, "Origin: https://evil.example", "Sec-Fetch-Site: cross-site" }).get("/rooms/zig/chat");
    defer res.deinit();
    try res.expectStatus(403);
}
