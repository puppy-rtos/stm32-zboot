const hal = @import("../hal.zig");
const Flash = @import("../fal/flash.zig");

pub fn flash_init(self: *const Flash.Flash_Dev) void {
    _ = self;
}
pub fn flash_earse(self: *const Flash.Flash_Dev, addr: u32, size: u32) void {
    _ = size;
    _ = addr;
    _ = self;
}
pub fn flash_write(self: *const Flash.Flash_Dev, addr: u32, data: []const u8) void {
    _ = data;
    _ = addr;
    _ = self;
}
pub fn flash_read(self: *const Flash.Flash_Dev, addr: u32, data: []u8) void {
    _ = self;

    // read data from onchip flash
    for (data, 0..) |*d, i| {
        d.* = @as(*u8, @ptrFromInt(addr + i)).*;
    }
}

pub const chip_flash: Flash.Flash_Dev = .{
    .name = "onchip",
    .start = 0x08000000,
    .len = 0x100000,
    .blocks = .{
        .{ .size = 0x4000, .count = 4 },
        .{ .size = 0x10000, .count = 1 },
        .{ .size = 0x20000, .count = 7 },
        .{ .size = 0x4000, .count = 4 },
        .{ .size = 0x10000, .count = 1 },
        .{ .size = 0x20000, .count = 7 },
    },
    .write_size = 8,
    .ops = .{
        .init = &flash_init,
        .erase = &flash_earse,
        .write = &flash_write,
        .read = &flash_read,
    },
};
