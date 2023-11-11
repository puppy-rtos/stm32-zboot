const std = @import("std");
const microzig = @import("microzig");
const regs = @import("regs/stm32f4.zig").devices.stm32f4.peripherals;
const types = @import("regs/stm32f4.zig").types;
const hal = @import("hal.zig");

var debug_writer: hal.uart.UartDebug().Writer = undefined;

pub fn show_logo() void {
    debug_writer.print("\r\n", .{}) catch {};
    debug_writer.print("{s}\r\n", .{"  _____   __                __ "}) catch {};
    debug_writer.print("{s}\r\n", .{" /__  /  / /_  ____  ____  / /_"}) catch {};
    debug_writer.print("{s}\r\n", .{"   / /  / __ \\/ __ \\/ __ \\/ __/"}) catch {};
    debug_writer.print("{s}\r\n", .{"  / /__/ /_/ / /_/ / /_/ / /_  "}) catch {};
    debug_writer.print("{s}\r\n", .{" /____/\\____/\\____/\\____/\\__/  "}) catch {};
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

pub fn flash_init() void {
    debug_writer.print("flash_init\r\n", .{}) catch {};
}
pub fn flash_earse(addr: u32, size: u32) void {
    debug_writer.print("flash_earse:addr:0x{x},size:0x{x}\r\n", .{ addr, size }) catch {};
}
pub fn flash_write(addr: u32, data: []const u8) void {
    debug_writer.print("flash_write:addr:0x{x}, data_ptr:0x{x}, size:{x} \r\n", .{ addr, @intFromPtr(data.ptr), data.len }) catch {};
    // dump data
    for (data, 0..) |*d, i| {
        if (i % 16 == 0) {
            debug_writer.print("0x{x:0>8}:", .{addr + i}) catch {};
        }
        debug_writer.print(" {x:0>2}", .{d.*}) catch {};
        if (i % 16 == 15) {
            debug_writer.print("\r\n", .{}) catch {};
        }
    }
    debug_writer.print("\r\n", .{}) catch {};
}
pub fn flash_read(addr: u32, data: []u8) void {
    debug_writer.print("flash_read:addr:0x{x}, data_ptr:0x{x}, size:{x}\r\n", .{ addr, @intFromPtr(data.ptr), data.len }) catch {};

    // read data from onchip flash
    for (data, 0..) |*d, i| {
        d.* = @as(*u8, @ptrFromInt(addr + i)).*;
    }

    // dump data
    for (data, 0..) |d, i| {
        if (i % 16 == 0) {
            debug_writer.print("0x{x:0>8}:", .{addr + i}) catch {};
        }
        debug_writer.print(" {x:0>2}", .{d}) catch {};
        if (i % 16 == 15) {
            debug_writer.print("\r\n", .{}) catch {};
        }
    }
    debug_writer.print("\r\n", .{}) catch {};
}

pub fn main() !void {
    hal.clock.clock_init();
    debug_writer = (try hal.uart.UartDebug().init("PA9")).writer();
    _ = debug_writer;

    show_logo();

    const flash1: hal.flash.Flash_Dev = .{
        .name = "flash1",
        .start = 0x08000000,
        .len = 0x100000,
        .block_size = 0x1000,
        .write_size = 8,
        .ops = .{
            .init = &flash_init,
            .erase = &flash_earse,
            .write = &flash_write,
            .read = &flash_read,
        },
    };
    flash1.init();
    flash1.erase(0x08000000, 0x1000);
    flash1.write(0x08000000, "hello");
    var buf: [5]u8 = undefined;
    flash1.read(0x08000000, &buf);

    jump_app();
}
