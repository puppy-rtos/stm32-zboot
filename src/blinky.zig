const std = @import("std");
const microzig = @import("microzig");
const regs = @import("regs/stm32f407.zig").devices.STM32F407.peripherals;

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

pub fn main() !void {
    var led = Led.init();
    while (true) {
        var i: u32 = 0;
        while (i < 800_000) {
            asm volatile ("nop");
            i += 1;
        }
        led.toggle();
    }
}
