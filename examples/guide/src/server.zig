//! The one server of this package: a route or two per subject of the guides.
const std = @import("std");
const spider = @import("spider");

/// What a main() would do to serve. The tests start it once
/// (`spider.testing.start(run)`) and share it.
pub fn run() !void {
    var server = spider.app(.{});
    defer server.deinit();

    try server
        .use(spider.loggerWith(.{ .quiet_paths = &.{ "/up", "/assets/**" } }))
        .use(spider.forceHttps(.{ .default_base_url = "https://guide.example" }))
        .get("/whoami", whoami, .{ .public = true })
        .post("/notes", addNote, .{ .public = true })
        .post("/hooks/payments", paymentHook, .{ .public = true, .allow_http = true })
        .post("/photos", addPhoto, .{ .public = true })
        .get("/photos/report", photoReport, .{ .public = true })
        .sseWith("/ticks", ticks, .{ .public = true })
        .listen(.{});
}

// ── who is asking ───────────────────────────────────────────────────────

/// The address of the visitor and the id of the request, as the app sees them.
fn whoami(c: *spider.Ctx) !spider.Response {
    return c.json(.{
        .ip = c.clientIp() orelse "unknown",
        .peer = c.peerAddress() orelse "unknown",
        .request_id = c.requestId(),
    }, .{});
}

fn addNote(c: *spider.Ctx) !spider.Response {
    return c.text("saved", .{ .status = .created });
}

fn paymentHook(c: *spider.Ctx) !spider.Response {
    return c.text("ok", .{});
}

/// A stream that says one thing and ends.
fn ticks(sse: *spider.Sse) !void {
    try sse.send("tick", .{ .n = 1 });
}

// ── files ───────────────────────────────────────────────────────────────

const max_photo_bytes = 200 * 1024;

/// Takes one image and a caption from a form with `enctype="multipart/form-data"`.
fn addPhoto(c: *spider.Ctx) !spider.Response {
    const form = try c.parseMultipart();
    const caption = form.getValue("caption") orelse "";
    const files = form.getFile("photo") orelse return c.text("Choose a photo.", .{ .status = .unprocessable_entity });
    const photo = files[0];

    // What the browser says about the file is not checked by anyone: the
    // app decides by the bytes, and never uses the name as a path.
    if (photo.size == 0) return c.text("The file is empty.", .{ .status = .unprocessable_entity });
    if (photo.size > max_photo_bytes) return c.text("The photo can have up to 200 KB.", .{ .status = .unprocessable_entity });
    if (!isPng(photo.data)) return c.text("Only PNG images.", .{ .status = .unprocessable_entity });

    // `photo.data` lives as long as the request: an app writes it to a
    // file or to storage here, under a name of its own making.
    return c.json(.{ .caption = caption, .bytes = photo.size, .sent_as = photo.filename }, .{ .status = .created });
}

fn isPng(bytes: []const u8) bool {
    return std.mem.startsWith(u8, bytes, "\x89PNG\r\n\x1a\n");
}

/// A file the browser saves instead of showing.
fn photoReport(c: *spider.Ctx) !spider.Response {
    const csv = "caption,bytes\nThe team,20480\n";
    return c.download(csv, .{ .filename = "photos.csv", .content_type = "text/csv" });
}
