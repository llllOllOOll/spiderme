const std = @import("std");
pub const spider = @import("spider");
pub const model = @import("model.zig");
pub const repository = @import("repository.zig");
pub const present = @import("present.zig");
pub const policy = @import("policy.zig");
pub const controller = @import("controller.zig");
pub const api = @import("api.zig");
pub const routes = @import("routes.zig");

// Makes the tests of this feature's files part of `zig build test`.
test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("routes_test.zig");
}
