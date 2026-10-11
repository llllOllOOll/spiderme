//! content/docs/push.md: notifications sent to a browser (Web Push).
const std = @import("std");
const spider = @import("spider");
const push = spider.push;

/// A push service of the test's own: it takes one request, keeps it, and
/// answers with the status it was told to. The real ones belong to the
/// browser makers.
const Service = @import("stub.zig").Stub;

/// What a browser hands the page when the visitor allows notifications:
/// where to send, and the two keys only that browser can read with. Here
/// they are made up; an app stores the ones each browser gave it.
const Browser = struct {
    keys: push.VapidKeys,
    p256dh: [87]u8,
    endpoint_buf: [64]u8 = undefined,

    fn init() Browser {
        const keys = push.WebPush.generateKeys(std.testing.io);
        return .{ .keys = keys, .p256dh = keys.publicKeyText() };
    }

    fn subscription(self: *Browser, service_port: u16) !push.PushSubscription {
        return .{
            .endpoint = try std.fmt.bufPrint(&self.endpoint_buf, "http://127.0.0.1:{d}/send/a1b2c3", .{service_port}),
            .p256dh = &self.p256dh,
            // 16 bytes, base64url without padding.
            .auth = "MDEyMzQ1Njc4OWFiY2RlZg",
        };
    }
};

test "push: the keys are made once; the public one goes to the page" {
    const keys = push.WebPush.generateKeys(std.testing.io);
    // The two values of the app's configuration.
    try std.testing.expectEqual(@as(usize, 43), keys.privateKeyText().len);
    try std.testing.expectEqual(@as(usize, 87), keys.publicKeyText().len);
    // Another call is another pair.
    const other = push.WebPush.generateKeys(std.testing.io);
    try std.testing.expect(!std.mem.eql(u8, &keys.publicKeyText(), &other.publicKeyText()));
}

test "push: a message goes to the browser's push service, encrypted and signed" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();

    // The app's identity: `spider generate-vapid` prints these three.
    const keys = push.WebPush.generateKeys(std.testing.io);
    const private_key = keys.privateKeyText();
    const public_key = keys.publicKeyText();
    const sender = push.WebPush.init(.{ .subject = "mailto:ops@guide.example", .private_key = &private_key, .public_key = &public_key });

    var service = try Service.listen("201 Created", "");
    const thread = try std.Thread.spawn(.{}, Service.serveOne, .{&service});
    var browser = Browser.init();

    const message =
        \\{"title":"Booking confirmed","body":"Cedar, tomorrow at 10:00","url":"/bookings/42"}
    ;
    // Kept for an hour if the device is offline.
    try sender.sendRaw(arena_state.allocator(), std.testing.io, try browser.subscription(service.port), message, 3600);
    thread.join();

    try std.testing.expect(service.got("POST /send/a1b2c3 "));
    try std.testing.expect(service.got("Authorization: vapid t="));
    try std.testing.expect(service.got("Content-Encoding: aes128gcm"));
    try std.testing.expect(service.got("TTL: 3600"));
    // The service carries the message and cannot read it.
    try std.testing.expect(!service.got("Booking confirmed"));
}

test "push: a subscription the browser dropped says so, and the app forgets it" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();

    const keys = push.WebPush.generateKeys(std.testing.io);
    const private_key = keys.privateKeyText();
    const public_key = keys.publicKeyText();
    const sender = push.WebPush.init(.{ .subject = "mailto:ops@guide.example", .private_key = &private_key, .public_key = &public_key });

    var service = try Service.listen("410 Gone", "");
    const thread = try std.Thread.spawn(.{}, Service.serveOne, .{&service});
    var browser = Browser.init();

    const result = sender.sendRaw(arena_state.allocator(), std.testing.io, try browser.subscription(service.port), "{}", 3600);
    thread.join();
    // Delete the subscription: it will never work again.
    try std.testing.expectError(error.PushSubscriptionExpired, result);
}

test "push: a message has a size limit" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();

    const keys = push.WebPush.generateKeys(std.testing.io);
    const private_key = keys.privateKeyText();
    const public_key = keys.publicKeyText();
    const sender = push.WebPush.init(.{ .subject = "mailto:ops@guide.example", .private_key = &private_key, .public_key = &public_key });
    var browser = Browser.init();

    const too_long: [push.max_payload_len + 1]u8 = @splat('x');
    try std.testing.expectError(error.PayloadTooLarge, sender.sendRaw(arena_state.allocator(), std.testing.io, try browser.subscription(1), &too_long, 60));
}
