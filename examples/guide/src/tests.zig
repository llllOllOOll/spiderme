//! The root of the tests: every file with tests is named here.
test {
    _ = @import("logging_test.zig");
    _ = @import("security_test.zig");
    _ = @import("uploads_test.zig");
    _ = @import("websocket_test.zig");
}
