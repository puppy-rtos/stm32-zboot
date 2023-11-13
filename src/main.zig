const std = @import("std");
const microzig = @import("microzig");
const regs = @import("regs/stm32f4.zig").devices.stm32f4.peripherals;
const types = @import("regs/stm32f4.zig").types;
const hal = @import("hal.zig");
const sys = @import("sys.zig");

const fal_partition = @import("fal/partition.zig");

pub fn show_logo() void {
    sys.debug.print("\r\n", .{}) catch {};
    sys.debug.print("{s}\r\n", .{"  _____   __                __ "}) catch {};
    sys.debug.print("{s}\r\n", .{" /__  /  / /_  ____  ____  / /_"}) catch {};
    sys.debug.print("{s}\r\n", .{"   / /  / __ \\/ __ \\/ __ \\/ __/"}) catch {};
    sys.debug.print("{s}\r\n", .{"  / /__/ /_/ / /_/ / /_/ / /_  "}) catch {};
    sys.debug.print("{s}\r\n", .{" /____/\\____/\\____/\\____/\\__/  "}) catch {};
}
const APP_ENTRY_ADDR = 0x08008000;
const APP_RAM_ADDR = 0x20000000;
const APP_RAM_SIZE = 0x00010000;

pub fn jump_app() void {
    const app_stack_addr = @as(*u32, @ptrFromInt(APP_ENTRY_ADDR)).*;
    // Check stack address
    if (app_stack_addr < APP_RAM_ADDR or app_stack_addr > APP_RAM_ADDR + APP_RAM_SIZE) {
        sys.debug.print("Invalid stack address: 0x{x}\r\n", .{app_stack_addr}) catch {};
        return;
    }
    const jump_addr = @as(*u32, @ptrFromInt(APP_ENTRY_ADDR + 4)).*;
    const jump2app: *const fn () void = @ptrFromInt(jump_addr);

    sys.debug.print("jump_addr:0x{x}\r\n", .{jump_addr}) catch {};

    microzig.cpu.peripherals.SysTick.CTRL.modify(.{ .ENABLE = 0 });
    regs.RCC.CFGR.raw = 0x00000000;
    jump2app();
}

pub fn main() !void {
    hal.clock.clock_init();
    sys.init_debug("PA9") catch {};
    show_logo();

    const flash1 = hal.chip_flash.chip_flash;
    flash1.init();

    const part1 = fal_partition.partition_find("app");
    if (part1) |part| {
        sys.debug.print("find partition:{s}\r\n", .{part.name}) catch {};
        fal_partition.partition_erase(part, 0, 100);
        fal_partition.partition_write(part, 8, "hello");
        var buf: [8]u8 = undefined;
        fal_partition.partition_read(part, 0, &buf);
    } else {
        sys.debug.print("not find partition\r\n", .{}) catch {};
    }

    jump_app();

    while (true) {}
}
