//! A server for tests that stands in for someone else's: it takes one
//! request, keeps what it was sent, and answers what it was told to.
const std = @import("std");

pub const Stub = struct {
    server: std.Io.net.Server,
    port: u16,
    status: []const u8,
    body: []const u8,
    received: [8192]u8 = undefined,
    len: usize = 0,

    pub fn listen(status: []const u8, body: []const u8) !Stub {
        const address = try std.Io.net.IpAddress.parse("127.0.0.1", 0);
        var server = try address.listen(std.testing.io, .{ .reuse_address = true });
        return .{ .port = server.socket.address.getPort(), .server = server, .status = status, .body = body };
    }

    /// Run it on a thread of its own: it returns once it has answered.
    pub fn serveOne(self: *Stub) void {
        const io = std.testing.io;
        var stream = self.server.accept(io) catch return;
        defer stream.close(io);
        var read_buf: [8192]u8 = undefined;
        var reader = stream.reader(io, &read_buf);
        // The head, then as many bytes as Content-Length says.
        while (true) {
            const chunk = reader.interface.peekGreedy(1) catch break;
            const n = @min(chunk.len, self.received.len - self.len);
            @memcpy(self.received[self.len..][0..n], chunk[0..n]);
            self.len += n;
            reader.interface.toss(chunk.len);
            const so_far = self.received[0..self.len];
            const head_end = std.mem.indexOf(u8, so_far, "\r\n\r\n") orelse continue;
            const at = std.ascii.findIgnoreCase(so_far, "content-length:") orelse break;
            const line_end = std.mem.indexOfPos(u8, so_far, at, "\r\n") orelse break;
            const length = std.fmt.parseInt(usize, std.mem.trim(u8, so_far[at + "content-length:".len .. line_end], " "), 10) catch break;
            if (self.len >= head_end + 4 + length) break;
        }
        var write_buf: [256]u8 = undefined;
        var writer = stream.writer(io, &write_buf);
        writer.interface.print("HTTP/1.1 {s}\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ self.status, self.body.len, self.body }) catch {};
        writer.interface.flush() catch {};
    }

    /// The same as a proxy: the caller first asks for a tunnel to the server
    /// it wants (CONNECT), is told it has one, and then sends its request
    /// through it. Both are kept, and the second one is answered.
    pub fn serveThroughTunnel(self: *Stub) void {
        const io = std.testing.io;
        var stream = self.server.accept(io) catch return;
        defer stream.close(io);
        var read_buf: [8192]u8 = undefined;
        var reader = stream.reader(io, &read_buf);
        var write_buf: [256]u8 = undefined;
        var writer = stream.writer(io, &write_buf);

        self.readHead(&reader.interface);
        writer.interface.writeAll("HTTP/1.1 200 Connection established\r\n\r\n") catch return;
        writer.interface.flush() catch return;

        self.readHead(&reader.interface);
        writer.interface.print("HTTP/1.1 {s}\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ self.status, self.body.len, self.body }) catch {};
        writer.interface.flush() catch {};
    }

    /// Reads up to the blank line that ends a request's head.
    fn readHead(self: *Stub, reader: *std.Io.Reader) void {
        const from = self.len;
        while (std.mem.indexOf(u8, self.received[from..self.len], "\r\n\r\n") == null) {
            const chunk = reader.peekGreedy(1) catch return;
            const n = @min(chunk.len, self.received.len - self.len);
            @memcpy(self.received[self.len..][0..n], chunk[0..n]);
            self.len += n;
            reader.toss(chunk.len);
        }
    }

    /// Whether the request had `text` in it (letter case ignored).
    pub fn got(self: *const Stub, text: []const u8) bool {
        return std.ascii.findIgnoreCase(self.received[0..self.len], text) != null;
    }
};
