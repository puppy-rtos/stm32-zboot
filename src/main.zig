const std = @import("std");
const microzig = @import("microzig");
const regs = @import("regs/stm32f407.zig").devices.STM32F407.peripherals;

pub fn main() !void {
    var led = Led.init();
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
