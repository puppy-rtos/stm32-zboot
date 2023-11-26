const std = @import("std");
const microzig = @import("microzig");

const hal = @import("hal/hal.zig");

const sys = @import("platform/sys.zig");
const fal = @import("platform/fal/fal.zig");
const sfud = @import("platform/sfud/sfud.zig");
const ota = @import("platform/ota/ota.zig");

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

    sys.debug.print("jump to app, addr:0x{x}\r\n", .{jump_addr}) catch {};

    hal.clock.clock_deinit();
    jump2app();
}
/// Contains references to the microzig .data and .bss sections, also
/// contains the initial load address for .data if it is in flash.
pub const sections = struct {
    // it looks odd to just use a u8 here, but in C it's common to use a
    // char when linking these values from the linkerscript. What's
    // important is the addresses of these values.
    extern var microzig_data_start: u8;
    extern var microzig_data_end: u8;
    extern var microzig_bss_start: u8;
    extern var microzig_bss_end: u8;
    extern const microzig_data_load_start: u8;
};

pub fn get_rom_end() usize {
    const data_start: [*]u8 = @ptrCast(&sections.microzig_data_start);
    const data_end: [*]u8 = @ptrCast(&sections.microzig_data_end);
    const data_len = @intFromPtr(data_end) - @intFromPtr(data_start);
    const data_src: u32 = @intFromPtr(&sections.microzig_data_load_start);
    return data_src + data_len;
}

pub fn main() !void {
    hal.clock.clock_init();
    sys.zconfig.probe_extconfig(get_rom_end());
    const zboot_config = sys.zconfig.get_config();
    if (zboot_config.uart.enable) {
        sys.init_debug(zboot_config.uart.tx[0..]) catch {};
        show_logo();
    }
    if (zboot_config.spiflash.enable) {
        const spi = try hal.spi.Spi(zboot_config.spiflash.mosi[0..], zboot_config.spiflash.miso[0..], zboot_config.spiflash.sck[0..], zboot_config.spiflash.cs[0..]);
        const spiflash = sfud.flash.probe("spiflash", spi);
        _ = spiflash;
    }

    fal.partition.init(get_rom_end());
    if (fal.partition.partition_table.num == 0) {
        sys.debug.print("partition table not find, use default partition\r\n", .{}) catch {};
        // load default partition
        fal.partition.init(@intFromPtr(&fal.partition.default_partition));
    }
    fal.partition.print();

    ota.swap();
    jump_app();

    while (true) {}
}
