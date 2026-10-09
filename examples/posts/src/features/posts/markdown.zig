//! Renders the body of a post, written in Markdown, as HTML.
//!
//! Spider's Markdown renderer (spider.zmd) escapes the text of a document,
//! but in Spider 0.9.0 it writes link addresses, link text, image titles and
//! the language of a code block as they were typed. Readers type these, so
//! this file replaces those three formatters with ones that escape them and
//! only keep addresses that are safe to follow.
const std = @import("std");
const spider = @import("spider");
const zmd = spider.zmd;

pub fn render(arena: std.mem.Allocator, body: []const u8) !spider.RawHtml {
    const html = try zmd.parse(arena, body, .{ .link = link, .image = image, .block = block });
    return .{ .html = html };
}

fn link(a: std.mem.Allocator, node: zmd.Node) std.mem.Allocator.Error![]const u8 {
    const text = try escape(a, node.title orelse "");
    const href = node.href orelse "";
    if (!safeAddress(href)) return text;
    return std.fmt.allocPrint(a, "<a href=\"{s}\">{s}</a>", .{ try escape(a, href), text });
}

fn image(a: std.mem.Allocator, node: zmd.Node) std.mem.Allocator.Error![]const u8 {
    const alt = try escape(a, node.title orelse "");
    const src = node.href orelse "";
    if (!safeAddress(src)) return alt;
    return std.fmt.allocPrint(a, "<img src=\"{s}\" alt=\"{s}\">", .{ try escape(a, src), alt });
}

/// A code block. The language after the opening fence is not shown.
fn block(a: std.mem.Allocator, node: zmd.Node) std.mem.Allocator.Error![]const u8 {
    return std.fmt.allocPrint(a, "<pre><code>{s}</code></pre>\n", .{node.content});
}

/// Web addresses, addresses inside this site and mail links. Anything else
/// (javascript:, data:) is left out.
fn safeAddress(address: []const u8) bool {
    for ([_][]const u8{ "https://", "http://", "mailto:", "/", "#" }) |start| {
        if (std.mem.startsWith(u8, address, start)) return true;
    }
    return false;
}

fn escape(a: std.mem.Allocator, text: []const u8) std.mem.Allocator.Error![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    for (text) |byte| switch (byte) {
        '&' => try out.appendSlice(a, "&amp;"),
        '<' => try out.appendSlice(a, "&lt;"),
        '>' => try out.appendSlice(a, "&gt;"),
        '"' => try out.appendSlice(a, "&quot;"),
        '\'' => try out.appendSlice(a, "&#39;"),
        else => try out.append(a, byte),
    };
    return out.items;
}

fn expectRendered(markdown: []const u8, expected: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const html = (try render(arena.allocator(), markdown)).html;
    try std.testing.expectEqualStrings(expected, std.mem.trim(u8, html, "\n"));
}

test "render keeps headings, lists and code" {
    try expectRendered("## What I deleted", "<h2>What I deleted</h2>");
    try expectRendered("Read `/posts/:id`.", "<p>Read <code>/posts/:id</code>.</p>");
    try expectRendered("```zig\nconst a = 1 < 2;\n```", "<pre><code>const a = 1 &lt; 2;</code></pre>");
}

test "render escapes HTML typed in the body" {
    try expectRendered("<script>alert(1)</script>", "<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>");
}

test "render escapes the text and the address of a link" {
    try expectRendered(
        "[<b>docs</b>](https://example.com/?a=1&b=2)",
        "<p><a href=\"https://example.com/?a=1&amp;b=2\">&lt;b&gt;docs&lt;/b&gt;</a></p>",
    );
    try expectRendered(
        "[x](https://a\" onmouseover=\"alert)",
        "<p><a href=\"https://a&quot; onmouseover=&quot;alert\">x</a></p>",
    );
}

test "render drops addresses that run code" {
    try expectRendered("[click](javascript:alert)", "<p>click</p>");
    try expectRendered("![pic](data:text/html;base64,AAAA)", "<p>pic</p>");
}

test "render does not show the language of a code block" {
    try expectRendered("```\"><script>alert(1)</script>\nx\n```", "<pre><code>x</code></pre>");
}
