pub const board = @import("board.zig");
pub const controller = @import("controller.zig");
pub const qr = @import("qr.zig");
pub const routes = @import("routes.zig");

// Makes the tests of this feature's files part of `zig build test`.
test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("routes_test.zig");
    _ = @import("board.zig");
    _ = @import("qr.zig");
}
