const std = @import("std");

const Flash = @import("../platform/fal/flash.zig");
const cpu = @import("../chip/cortex-m.zig");

pub var chip_flash: Flash.Flash_Dev = undefined;

pub fn init() void {
    if (@import("../hal/hal.zig").chip_series == @import("../hal/hal.zig").ChipSeriseType.STM32F4) {
        chip_flash = @import("../chip/stm32f4/flash.zig").chip_flash;
    } else if (@import("../hal/hal.zig").chip_series == @import("../hal/hal.zig").ChipSeriseType.STM32L4) {
        chip_flash = @import("../chip/stm32l4/flash.zig").chip_flash;
    } else if (@import("../hal/hal.zig").chip_series == @import("../hal/hal.zig").ChipSeriseType.STM32H7) {
        chip_flash = @import("../chip/stm32h7/flash.zig").chip_flash;
    }
}
