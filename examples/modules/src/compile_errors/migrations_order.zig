//! Does not compile, on purpose: migrations listed out of order.
const spider = @import("spider");

const audit = struct {
    pub const spider_module = spider.module(.{
        .name = "audit",
        .version = "0.2.0",
        .spider = ">=0.11.0 <0.12.0",
        .migrations = .{
            .{ .name = "0002_actor", .sql = "ALTER TABLE audit_events ADD COLUMN actor TEXT;" },
            .{ .name = "0001_init", .sql = "CREATE TABLE audit_events (id BIGINT PRIMARY KEY);" },
        },
    });
};

test {
    _ = audit.spider_module;
}
