const std = @import("std");

const cpu = @import("../chip/cortex-m.zig");

pub const ClockType = struct {
    // init the flash
    init: *const fn () void,
    // write the flash
    deinit: *const fn () void,
    // read the flash
    get_sysfreq: *const fn () u32,
};

var clock: ClockType = undefined;
var sysfreq: u32 = 0;

pub fn init() void {
    if (@import("../hal/hal.zig").chip_series == @import("../hal/hal.zig").ChipSeriseType.STM32F4) {
        clock = @import("../chip/stm32f4/clock.zig").clock;

        clock.init();
        sysfreq = clock.get_sysfreq();
    } else if (@import("../hal/hal.zig").chip_series == @import("../hal/hal.zig").ChipSeriseType.STM32L4) {
        clock = @import("../chip/stm32l4/clock.zig").clock;

        clock.init();
        sysfreq = clock.get_sysfreq();
    } else if (@import("../hal/hal.zig").chip_series == @import("../hal/hal.zig").ChipSeriseType.STM32H7) {
        clock = @import("../chip/stm32h7/clock.zig").clock;

        clock.init();
        sysfreq = clock.get_sysfreq();
    }
}

pub fn deinit() void {
    clock.deinit();
}

// delay_ms
pub fn delay_ms(ms: u32) void {
    for (0..ms) |i| {
        _ = i;
        delay_us(1000);
    }
}

// delay us
pub fn delay_us(us: u32) void {
    var ticks: u32 = 0;
    var start: u32 = 0;
    var current: u32 = 0;

    ticks = us * (sysfreq / 1000000);
    start = cpu.peripherals.SysTick.VAL.read().CURRENT;
    while (true) {
        current = cpu.peripherals.SysTick.VAL.read().CURRENT;
        if (start < current) {
            current = start + (0xFFFFFF - current);
        } else {
            current = start - current;
        }
        if (current > ticks) {
            break;
        }
    }
}
