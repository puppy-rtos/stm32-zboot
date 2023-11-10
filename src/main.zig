const std = @import("std");
const microzig = @import("microzig");
const regs = @import("regs/stm32f4.zig").devices.stm32f4.peripherals;
const types = @import("regs/stm32f4.zig").types;
const hal = @import("hal.zig");

var debug_writer: hal.uart.UartDebug().Writer = undefined;

pub fn show_logo() void {
    debug_writer.print("{s}\r\n", .{"  _____   __                __ "}) catch {};
    debug_writer.print("{s}\r\n", .{" /__  /  / /_  ____  ____  / /_"}) catch {};
    debug_writer.print("{s}\r\n", .{"   / /  / __ \\/ __ \\/ __ \\/ __/"}) catch {};
    debug_writer.print("{s}\r\n", .{"  / /_ / /_/ / /_/ / /_/ / /_  "}) catch {};
    debug_writer.print("{s}\r\n", .{" /____/\\.___/\\____/\\____/\\__/  "}) catch {};
}
const APP_ENTRY_ADDR = 0x08008000;
const APP_RAM_ADDR = 0x20000000;
const APP_RAM_SIZE = 0x00010000;

pub fn jump_app() void {
    const app_stack_addr = @as(*u32, @ptrFromInt(APP_ENTRY_ADDR)).*;
    // Check stack address
    if (app_stack_addr < APP_RAM_ADDR or app_stack_addr > APP_RAM_ADDR + APP_RAM_SIZE) {
        debug_writer.print("Invalid stack address: 0x{x}\r\n", .{app_stack_addr}) catch {};
        return;
    }
    const jump_addr = @as(*u32, @ptrFromInt(APP_ENTRY_ADDR + 4)).*;
    const jump2app: *const fn () void = @ptrFromInt(jump_addr);

    debug_writer.print("jump_addr:0x{x}\r\n", .{jump_addr}) catch {};
    jump2app();
}

pub fn main() !void {
    hal.clock.clock_init();
    debug_writer = (try hal.uart.UartDebug().init("PA9")).writer();
    _ = debug_writer;

    show_logo();

    jump_app();

    var led = try Led.init("PC13");

    while (true) {
        led.toggle();
        hal.clock.delay_ms(1000);
    }
}

const Led = struct {
    state: bool,
    pin: hal.Pin,

    pub fn init(name: []const u8) !@This() {
        var self = Led{ .state = false, .pin = try hal.Pin.init(name) };
        return self;
    }

    pub fn on(self: *@This()) void {
        self.state = true;
        self.pin.clear();
    }

    pub fn off(self: *@This()) void {
        self.state = false;
        self.pin.set();
    }

    pub fn toggle(self: *@This()) void {
        if (self.state) {
            self.off();
        } else {
            self.on();
        }
    }
};
