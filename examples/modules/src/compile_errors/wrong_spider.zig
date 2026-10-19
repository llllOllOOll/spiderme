//! Does not compile, on purpose: a module tested with a later Spider.
const spider = @import("spider");

const old_widget = struct {
    pub const spider_module = spider.module(.{
        .name = "old_widget",
        .version = "2.0.0",
        .spider = ">=0.12.0 <0.13.0",
    });
};

test {
    _ = old_widget.spider_module;
}
