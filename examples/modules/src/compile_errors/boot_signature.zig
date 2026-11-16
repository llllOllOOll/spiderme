//! Does not compile, on purpose: a boot() Spider could not call.
const spider = @import("spider");

const late = struct {
    pub const spider_module = spider.module(.{
        .name = "late",
        .version = "0.1.0",
        .spider = ">=0.11.0 <0.15.0",
    });

    pub fn boot() void {}
};

test {
    var server = spider.app(.{});
    defer server.deinit();
    _ = server.mountModules(.{late});
}
