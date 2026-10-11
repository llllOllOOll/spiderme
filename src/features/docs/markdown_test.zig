//! What `spider.zmd` makes of Markdown: the examples of content/docs/markdown.md.
const std = @import("std");
const spider = @import("spider");

test "markdown: what an author types, and the HTML that comes out" {
    const text =
        \\## A heading
        \\
        \\Some **bold**, *italic* and `code`, and a [link](https://example.org).
        \\
        \\- one
        \\- two
        \\
        \\1. first
        \\2. second
        \\
        \\> Someone said this.
        \\
        \\![A diagram](/img/diagram.png)
    ;
    const html = try spider.zmd.parse(std.testing.allocator, text, .{});
    defer std.testing.allocator.free(html);

    try std.testing.expectEqualStrings(
        \\<h2>A heading</h2>
        \\<p>Some <b>bold</b>, <i>italic</i> and <code>code</code>, and a <a href="https://example.org">link</a>.</p>
        \\<ul>
        \\  <li>one</li>
        \\  <li>two</li>
        \\</ul>
        \\<ol>
        \\  <li>first</li>
        \\  <li>second</li>
        \\</ol>
        \\<blockquote>Someone said this.</blockquote>
        \\<p><img src="/img/diagram.png" title="A diagram"></p>
        \\
    , html);
}

test "markdown: a block of code keeps its language and escapes its text" {
    const text =
        \\```zig
        \\const smaller = 1 < 2;
        \\```
    ;
    const html = try spider.zmd.parse(std.testing.allocator, text, .{});
    defer std.testing.allocator.free(html);

    try std.testing.expectEqualStrings(
        \\<div class="code-block">
        \\  <div class="code-block-bar"><span class="code-block-lang">zig</span></div>
        \\  <pre><code>const smaller = 1 &lt; 2;</code></pre>
        \\</div>
        \\
    , html);
}

test "markdown: HTML an author types is shown, not run; a link that would run a script is dropped" {
    const text = "<script>alert(1)</script> and [a trap](javascript:alert(1))";
    const html = try spider.zmd.parse(std.testing.allocator, text, .{});
    defer std.testing.allocator.free(html);

    try std.testing.expect(std.mem.indexOf(u8, html, "<script>") == null);
    try std.testing.expect(std.mem.indexOf(u8, html, "&lt;script&gt;alert(1)&lt;/script&gt;") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "javascript:") == null);
    try std.testing.expect(std.mem.indexOf(u8, html, "<a ") == null);
}

fn titled(allocator: std.mem.Allocator, node: spider.zmd.Node) std.mem.Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "<h2 class=\"title\">{s}</h2>\n", .{node.content});
}

test "markdown: a formatter of the app's own writes one kind of element" {
    const html = try spider.zmd.parse(std.testing.allocator, "## Prices", .{ .h2 = titled });
    defer std.testing.allocator.free(html);
    try std.testing.expectEqualStrings("<h2 class=\"title\">Prices</h2>\n", html);
}

test "markdown: parseFull gives a whole document" {
    const html = try spider.zmd.parseFull(std.testing.allocator, "# Notes", .{});
    defer std.testing.allocator.free(html);
    try std.testing.expect(std.mem.startsWith(u8, html, "<!DOCTYPE html>"));
    try std.testing.expect(std.mem.indexOf(u8, html, "<h1>Notes</h1>") != null);
}
