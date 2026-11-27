//! A page with a misspelled component: `<ProdctCard />`, with no file of
//! that name. It does not compile, and the build checks that it does not.
const spider = @import("spider");

/// The handler that renders it.
pub fn shopTypo(c: *spider.Ctx) !spider.Response {
    return c.view("shop/typo", .{}, .{});
}

test "a tag no file answers to stops the build" {
    _ = &shopTypo;
}
