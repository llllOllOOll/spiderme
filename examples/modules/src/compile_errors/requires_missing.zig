//! Does not compile, on purpose: a module whose requirement is not mounted.
const spider = @import("spider");

const billing = struct {
    pub const spider_module = spider.module(.{
        .name = "billing",
        .version = "1.0.0",
        .spider = ">=0.11.0 <0.12.0",
        .requires = .{"audit"},
    });
};

test {
    var server = spider.app(.{});
    defer server.deinit();
    _ = server.mountModules(.{billing});
}
