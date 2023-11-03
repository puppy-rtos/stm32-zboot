const std = @import("std");
const microzig = @import("microzig");
const regs = @import("regs/stm32f4.zig").devices.stm32f4.peripherals;
const types = @import("regs/stm32f4.zig").types;

const FLASH_NAME_MAX = 16;
const PIN_NAME_MAX = 8;

const FlashPartition = struct {
    const magic: u32 = 0x45503130;
    name: [FLASH_NAME_MAX]u8,
    flash_name: [FLASH_NAME_MAX]u8,
    offset: u32,
    size: u32,
    reserved: [4]u8,
};

const zboot_config = struct {
    const ram_size: u16 = 16; // unit: k
    const flash_size: u16 = 512; // unit: k
    const spiflash = struct {
        const enable: bool = false;
        const name: [FLASH_NAME_MAX]u8 = "spiflash";
        const spi = struct {
            const miso: [PIN_NAME_MAX]u8 = "PA6";
            const mosi: [PIN_NAME_MAX]u8 = "PA7";
            const sck: [PIN_NAME_MAX]u8 = "PA5";
            const cs: [PIN_NAME_MAX]u8 = "PA4";
        };
    };
    const uart = struct {
        const enable: bool = true;
        const tx: [PIN_NAME_MAX]u8 = "PA9";
        const rx: [PIN_NAME_MAX]u8 = "PA10";
    };
    const recovery = struct {
        const enable: bool = false;
        const active_level: bool = false;
        const pin: [PIN_NAME_MAX]u8 = "PA0";
    };
    partition: []FlashPartition,
};

const Pin = struct {
    port: *volatile types.peripherals.GPIOA,
    pin: u8,

    pub fn init(name: []const u8) !@This() {
        var port_num = name[1] - 'A';
        var port_addr: u32 = 0x40020000 + 0x400 * @as(u32, port_num);
        var pin_num: u32 = try parseU32(name[2..]);
        var self: Pin = Pin{ .port = @as(*volatile types.peripherals.GPIOA, @ptrFromInt(port_addr)), .pin = @intCast(pin_num) };

        var moder_addr = @intFromPtr(&self.port.MODER);
        var moder: *volatile u32 = @ptrFromInt(moder_addr);

        var moder13 = moder.*;
        _ = moder13;
        // moder.MODER13 = 0b01;
        return self;
    }
};

pub fn main() !void {
    var led = Led.init();
    var pin = try Pin.init("PC13");
    _ = pin;
    while (true) {
        delay(500);
        led.toggle();
    }
}

const Led = struct {
    state: bool,

    pub fn init() @This() {
        // Enable GPIOC port
        regs.RCC.AHB1ENR.modify(.{ .GPIOCEN = 1 });
        // Set GPIOC pin 13 to output
        regs.GPIOC.MODER.modify(.{ .MODER13 = 0b01 });
        var self = Led{ .state = false };
        return self;
    }

    pub fn on(self: *@This()) void {
        self.state = true;
        // Set GPIOC pin 13 to put high
        regs.GPIOC.ODR.modify(.{ .ODR13 = 0 });
    }

    pub fn off(self: *@This()) void {
        self.state = false;
        // Set GPIOC pin 13 to put low
        regs.GPIOC.ODR.modify(.{ .ODR13 = 1 });
    }

    pub fn toggle(self: *@This()) void {
        if (self.state) {
            self.off();
        } else {
            self.on();
        }
    }
};

fn parseU32(input: []const u8) !u32 {
    var tmp: u32 = 0;
    for (input) |c| {
        const digit = try std.fmt.charToDigit(c, 10);
        tmp = tmp * 10 + @as(u32, digit);
    }
    return tmp;
}

pub fn delay(ms: u32) void {
    // CPU run at 16mHz on HSI16
    // each tick is 5 instructions (1000 * 16 / 5) = 3200
    var ticks = ms * (1000 * 16 / 5);
    var i: u32 = 0;
    // One loop is 5 instructions
    while (i < ticks) {
        microzig.cpu.nop();
        i += 1;
    }
}
