//! content/docs/spreadsheets.md and content/docs/qrcode.md.
const std = @import("std");
const spider = @import("spider");
const run = @import("server.zig").run;

test "xlsx: the export is a file Excel opens, and reading it back gives the same rows" {
    const app = try spider.testing.start(run);
    var res = try app.get("/orders.xlsx");
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectHeader("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    try res.expectHeader("Content-Disposition", "attachment; filename=\"orders.xlsx\"");

    const book = try spider.xlsx.Reader.open(std.testing.allocator, res.body, .{});
    defer book.deinit();
    try std.testing.expectEqualStrings("Orders", book.sheets()[0].name);

    const rows = try book.rows(0, .{});
    defer rows.deinit();

    const heading = (try rows.next()).?;
    try std.testing.expectEqualStrings("Customer", heading.cells[0].value.text);

    const first = (try rows.next()).?;
    try std.testing.expectEqual(@as(u32, 1), first.number);
    try std.testing.expectEqualStrings("Ana Ribeiro", first.cells[0].value.text);
    try std.testing.expectEqual(@as(f64, 3), first.cells[1].value.number);
    try std.testing.expectEqual(@as(f64, 149.70), first.cells[2].value.number);
    // A number carries the format it is shown with.
    try std.testing.expectEqualStrings("#,##0.00", first.cells[2].format);
}

/// A form with one file, as a browser sends it.
fn upload(arena: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    return std.mem.concat(arena, u8, &.{
        "--edge\r\nContent-Disposition: form-data; name=\"sheet\"; filename=\"orders.xlsx\"\r\n\r\n",
        bytes,
        "\r\n--edge--\r\n",
    });
}

const multipart = &.{"Content-Type: multipart/form-data; boundary=edge"};

test "xlsx: an uploaded spreadsheet is read row by row" {
    const app = try spider.testing.start(run);
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();

    var exported = try app.get("/orders.xlsx");
    defer exported.deinit();

    var res = try app.request(.{ .method = "POST", .target = "/orders/import", .headers = multipart, .body = try upload(arena_state.allocator(), exported.body) });
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectContains("\"orders\":3");
    try res.expectContains("\"items\":16");
}

test "xlsx: a file that is not a spreadsheet is refused, not read" {
    const app = try spider.testing.start(run);
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();

    var res = try app.request(.{ .method = "POST", .target = "/orders/import", .headers = multipart, .body = try upload(arena_state.allocator(), "name,items\nAna,3\n") });
    defer res.deinit();
    try res.expectStatus(422);
    try res.expectContains("That is not a spreadsheet this app can read.");
}

test "qrcode: a link becomes a square of modules, drawn as SVG" {
    const app = try spider.testing.start(run);
    var res = try app.get("/tickets/A7K2/qr.svg");
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectHeader("Content-Type", "image/svg+xml");
    // 33 characters at the medium level fit version 3: 29 modules a side,
    // plus the margin of 4 on each.
    try res.expectContains("viewBox=\"0 0 37 37\"");
    // The corner a scanner looks for starts at the margin.
    try res.expectContains("<rect x=\"4\" y=\"4\" width=\"1\" height=\"1\"/>");
}

test "qrcode: the size follows the text, and a text too long is an error" {
    const a = std.testing.allocator;
    var short = try spider.qrcode.QR.encodeAuto(a, "HELLO", .medium);
    defer short.deinit();
    try std.testing.expectEqual(@as(u16, 21), short.size);

    var longer = try spider.qrcode.QR.encodeAuto(a, "https://guide.example/tickets/A7K2?from=mail&lang=en", .medium);
    defer longer.deinit();
    try std.testing.expect(longer.size > short.size);

    const huge: [4000]u8 = @splat('x');
    try std.testing.expectError(error.DataTooLarge, spider.qrcode.QR.encodeAuto(a, &huge, .high));
}
