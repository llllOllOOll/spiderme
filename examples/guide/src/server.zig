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
        .wsWith("/rooms/:room/chat", chat, .{ .public = true })
        .wsWith("/staff/feed", staffFeed, .{ .authenticated = true })
        .get("/orders.xlsx", exportOrders, .{ .public = true })
        .post("/orders/import", importOrders, .{ .public = true })
        .get("/tickets/:code/qr.svg", ticketQr, .{ .public = true })
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

// ── a socket ────────────────────────────────────────────────────────────

/// A chat room: what one connection says, everyone in the same room hears.
fn chat(ws: *spider.Ws) !void {
    const room = ws.param("room") orelse return;
    try ws.join(room);
    try ws.send("welcome");

    // Until the visitor leaves. When the handler returns, the socket closes.
    while (try ws.next()) |message| {
        ws.broadcastTo(room, message.data);
    }
}

fn staffFeed(ws: *spider.Ws) !void {
    while (try ws.next()) |_| {}
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

// ── a spreadsheet ───────────────────────────────────────────────────────

const xlsx = spider.xlsx;

const Order = struct { customer: []const u8, items: i64, total: f64 };

const orders = [_]Order{
    .{ .customer = "Ana Ribeiro", .items = 3, .total = 149.70 },
    .{ .customer = "Bo Larsen", .items = 1, .total = 49.90 },
    .{ .customer = "Cy Okafor", .items = 12, .total = 598.80 },
};

/// The orders as an Excel file the browser saves.
fn exportOrders(c: *spider.Ctx) !spider.Response {
    const book = try xlsx.Workbook.init(c.arena);
    defer book.deinit();

    const sheet = try book.addSheet("Orders");
    try sheet.setColumnWidth(0, 28);

    // Rows and columns count from zero: this is the first row.
    const heading: xlsx.Style = .{ .bold = true, .fill = 0xDDEEFF, .border = .thin };
    try sheet.setRow(0, 0, &.{ .{ .text = "Customer" }, .{ .text = "Items" }, .{ .text = "Total" } }, heading);

    for (orders, 1..) |order, row| {
        const r: u32 = @intCast(row);
        try sheet.set(r, 0, .{ .text = order.customer });
        try sheet.set(r, 1, .int(order.items));
        try sheet.setStyled(r, 2, .{ .number = order.total }, .{ .number_format = .thousands_decimal });
    }

    // The heading stays in view while the rows scroll, with filter buttons.
    try sheet.freeze(1, 0);
    try sheet.setAutoFilter(.{ .first_row = 0, .first_col = 0, .last_row = orders.len, .last_col = 2 });

    return c.download(try book.toOwnedSlice(c.arena), .{
        .filename = "orders.xlsx",
        .content_type = spider.content_types.xlsx,
    });
}

/// Reads a spreadsheet someone uploaded: a heading, then one order per row.
fn importOrders(c: *spider.Ctx) !spider.Response {
    const form = try c.parseMultipart();
    const files = form.getFile("sheet") orelse return c.text("Choose a file.", .{ .status = .unprocessable_entity });

    // The default limits are for files from strangers: size, rows, and
    // how far a small file may expand.
    const book = xlsx.Reader.open(c.arena, files[0].data, .{}) catch {
        return c.text("That is not a spreadsheet this app can read.", .{ .status = .unprocessable_entity });
    };
    defer book.deinit();

    const rows = try book.rows(0, .{});
    defer rows.deinit();

    var count: usize = 0;
    var items: f64 = 0;
    while (try rows.next()) |row| {
        if (row.number == 0) continue; // the heading
        var customer: []const u8 = "";
        var quantity: f64 = 0;
        // A row only has the cells that were filled: go by `cell.column`,
        // not by position.
        for (row.cells) |cell| switch (cell.column) {
            0 => switch (cell.value) {
                .text => |text| customer = text,
                else => {},
            },
            1 => switch (cell.value) {
                .number => |n| quantity = n,
                else => {},
            },
            else => {},
        };
        if (customer.len == 0) continue;
        count += 1;
        items += quantity;
    }
    return c.json(.{ .orders = count, .items = items }, .{});
}

// ── a QR code ───────────────────────────────────────────────────────────

/// A ticket's link as a QR code, drawn as SVG.
fn ticketQr(c: *spider.Ctx) !spider.Response {
    const code = c.params.get("code") orelse return error.NotFound;
    const link = try std.fmt.allocPrint(c.arena, "https://guide.example/tickets/{s}", .{code});

    const qr = try spider.qrcode.QR.encodeAuto(c.arena, link, .medium);

    // A scanner needs a light margin around the code: four modules.
    const margin = 4;
    const side = qr.size + 2 * margin;
    var svg: std.ArrayList(u8) = .empty;
    try svg.print(c.arena,
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {d} {d}" shape-rendering="crispEdges">
        \\<rect width="{d}" height="{d}" fill="#fff"/>
        \\
    , .{ side, side, side, side });
    for (0..qr.size) |y| {
        for (0..qr.size) |x| {
            if (!qr.getModule(@intCast(x), @intCast(y))) continue;
            try svg.print(c.arena, "<rect x=\"{d}\" y=\"{d}\" width=\"1\" height=\"1\"/>", .{ x + margin, y + margin });
        }
    }
    try svg.appendSlice(c.arena, "</svg>\n");

    return c.download(svg.items, .{
        .filename = "ticket.svg",
        .content_type = "image/svg+xml",
        .disposition = .@"inline",
    });
}
