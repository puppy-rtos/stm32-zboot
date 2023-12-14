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
var APP_ENTRY_ADDR: usize = 0x08008000;
const APP_RAM_ADDR = 0x20000000;
const APP_RAM_SIZE = 0x00010000;

pub fn jump_app() void {
    const app = fal.partition.find("app").?;

    const ret = ota.get_fw_info(app, true);
    if (ret == null) {
        sys.debug.print("unkown app\r\n", .{}) catch {};
    } else {
        const ota_fw_info = ret.?;
        sys.debug.print("find app version:{s}\r\n", .{ota_fw_info.version}) catch {};
    }

    const flash = fal.flash.find(app.flash_name[0..]).?;
    APP_ENTRY_ADDR = flash.start + app.offset;

    const app_stack_addr = @as(*u32, @ptrFromInt(APP_ENTRY_ADDR)).*;
    // Check stack address
    if (app_stack_addr < APP_RAM_ADDR or app_stack_addr > APP_RAM_ADDR + APP_RAM_SIZE) {
        sys.debug.print("Can't find app @0x{x}\r\n", .{APP_ENTRY_ADDR}) catch {};
        return;
    }
    const jump_addr = @as(*u32, @ptrFromInt(APP_ENTRY_ADDR + 4)).*;
    const jump2app: *const fn () void = @ptrFromInt(jump_addr);

    // sys.debug.print("jump to app, offset:0x{x}, addr:0x{x}\r\n", .{ APP_ENTRY_ADDR, jump_addr }) catch {};

    hal.clock.clock_deinit();
    jump2app();
}

pub fn main() !void {
    hal.clock.clock_init();
    sys.zconfig.probe_extconfig(sys.get_rom_end());
    const zboot_config = sys.zconfig.get_config();
    if (zboot_config.uart.enable) {
        sys.init_debug(zboot_config.uart.tx[0..]) catch {};
        show_logo();
    }
    if (zboot_config.spiflash.enable) {
        const spi = try hal.spi.Spi(zboot_config.spiflash.mosi[0..], zboot_config.spiflash.miso[0..], zboot_config.spiflash.sck[0..], zboot_config.spiflash.cs[0..]);
        const spiflash = sfud.flash.probe("spiflash", spi);
        // dump spiflash info
        if (spiflash) |flash| {
            _ = flash.init();
        } else {
            sys.debug.print("spiflash not find\r\n", .{}) catch {};
        }
    }
    fal.init();

    // ota check app crc
    if (ota.checkFW("app") == false) {
        sys.debug.print("app check failed\r\n", .{}) catch {};
    }

    try ota.swap();
    jump_app();

    while (true) {}
}
