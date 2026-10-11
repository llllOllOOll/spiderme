//! content/docs/http-client.md: calls that leave through a proxy, and
//! calls that show a client certificate.
const std = @import("std");
const spider = @import("spider");
const Stub = @import("stub.zig").Stub;

test "proxy: the call asks the proxy for a way to the server, then goes through it" {
    // The proxy of the test, which is also the server at the other end.
    var proxy = try Stub.listen("200 OK", "1 EUR = 6.21 BRL");
    const thread = try std.Thread.spawn(.{}, Stub.serveThroughTunnel, .{&proxy});

    var url_buf: [64]u8 = undefined;
    const proxy_url = try std.fmt.bufPrint(&url_buf, "http://ana:s3cret@127.0.0.1:{d}", .{proxy.port});

    var res = try spider.http_client.get(std.testing.io, std.testing.allocator, "http://rates.example/today?base=EUR", .{
        .proxy_url = proxy_url,
        .timeout_ms = 3000,
    });
    defer res.deinit();
    thread.join();

    try std.testing.expectEqualStrings("1 EUR = 6.21 BRL", res.body_text);
    // First, the way: which server, and who is asking ("ana:s3cret").
    try std.testing.expect(proxy.got("CONNECT rates.example:80 HTTP/1.1"));
    try std.testing.expect(proxy.got("Proxy-Authorization: Basic YW5hOnMzY3JldA=="));
    // Then the request itself, as the server would get it without a proxy.
    try std.testing.expect(proxy.got("GET /today?base=EUR HTTP/1.1"));
}

test "proxy: a client is tied to the proxy it was made with" {
    var client = try spider.http_client.Client.init(std.testing.io, std.testing.allocator, .{
        .base_url = "http://rates.example",
        .proxy_url = "http://127.0.0.1:3128",
    });
    defer client.deinit();

    try std.testing.expectError(error.ProxyMismatch, client.get("/today", .{ .proxy_url = "http://127.0.0.1:9999" }));
}

test "client certificate: a server that is not there is an error by name" {
    const gpa = std.testing.allocator;
    const certificate: spider.http_client_mtls.MtlsCert = .{ .pem = .{
        .cert = "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----\n",
        .key = "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
    } };

    // Nothing listens on port 1.
    const result = spider.http_client_mtls.request(gpa, "https://127.0.0.1:1/accounts", certificate, .{
        .method = .POST,
        .headers = &.{.{ "Content-Type", "application/json" }},
        .body = "{\"account\":7}",
        .timeout_ms = 2000,
    });
    if (result) |ok| {
        var res = ok;
        res.deinit(gpa);
        return error.TestUnexpectedResult;
    } else |err| {
        try std.testing.expectEqual(error.MtlsTransportFailed, err);
    }
}
