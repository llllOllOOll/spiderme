//! The root of the tests: every file with tests is named here.
test {
    _ = @import("files_test.zig");
    _ = @import("htmx_test.zig");
    _ = @import("logging_test.zig");
    _ = @import("outbound_test.zig");
    _ = @import("push_test.zig");
    _ = @import("security_test.zig");
    _ = @import("storage_test.zig");
    _ = @import("uploads_test.zig");
    _ = @import("websocket_test.zig");
}
