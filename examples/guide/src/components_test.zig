//! content/docs/components.md: a page made of components.
const std = @import("std");
const spider = @import("spider");
const run = @import("server.zig").run;

test "components: a page is its layout, a panel, and a card for each product" {
    const app = try spider.testing.start(run);
    var res = try app.get("/shop");
    defer res.deinit();
    try res.expectStatus(200);

    // The layout, with the page in its slot.
    try res.expectContains("<h1 id=\"page-title\">Shop</h1>");
    // <Panel heading="Products">: its attribute, and what was inside the tag.
    try res.expectContains("<h2>Products</h2>");
    try res.expectContains("<div class=\"panel-body\">");
    // <ResultCount />, inside the panel's tag, read `count` from the page too.
    try res.expectContains("3 found");
    // <ProductList /> took no attribute: it read `products` from the page.
    // <ProductCard> got one product on each turn of the loop.
    try res.expectContains("<article class=\"card\" id=\"product-1\">");
    try res.expectContains("<a href=\"/shop/3\">Desk lamp</a>");
    // What an attribute carries is escaped where it is printed, once.
    try res.expectContains("Pen &amp; ink set");
    // <PriceTag>, inside the card, chose its own markup.
    try res.expectContains("<span class=\"price price-sale\">$12.00</span>");
    try res.expectContains("<span class=\"price\">$4.50</span>");
}

test "components: htmx gets the parts that change, each one a component" {
    const app = try spider.testing.start(run);
    var res = try app.with(&.{"HX-Request: true"}).get("/shop?q=lamp");
    defer res.deinit();
    try res.expectStatus(200);

    // No layout and no panel: the list, then the count.
    try std.testing.expect(std.mem.startsWith(u8, res.body, "<div id=\"products\">"));
    try res.expectContains("Desk lamp");
    try res.expectNotContains("Notebook");
    try res.expectContains("<p id=\"result-count\" hx-swap-oob=\"true\">1 found</p>");
    try res.expectNotContains("<html");
}

test "components: a tag no file answers to prints nothing, and says nothing" {
    const app = try spider.testing.start(run);
    var res = try app.get("/shop/typo");
    defer res.deinit();
    try res.expectStatus(200);
    try res.expectContains("<p>before</p>");
    try res.expectContains("<p>after</p>");
    try res.expectNotContains("Notebook");
}

test "components: one defined in the page that uses it" {
    const app = try spider.testing.start(run);
    var res = try app.get("/shop/receipt");
    defer res.deinit();
    try res.expectContains("<tr><td>Notebook</td><td>$4.50</td></tr>");
    try res.expectContains("<tr><td>Total</td><td>$7.50</td></tr>");
    // The definition itself is not printed.
    try res.expectNotContains("<Line");
    try res.expectNotContains("{ label }");
}
