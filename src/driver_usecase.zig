const Driver = @import("models/driver.zig").Driver;
const DriverRepository = @import("driver_repository.zig");

const DriverUsecase = @This();

repo: DriverRepository,

pub fn init(repo: DriverRepository) DriverUsecase {
    return .{ .repo = repo };
}

pub fn getDrivers(self: DriverUsecase) ![]Driver {
    return self.repo.findAll();
}
