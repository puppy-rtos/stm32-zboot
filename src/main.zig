const std = @import("std");
const microzig = @import("microzig");
const regs = @import("regs/stm32f4.zig").devices.stm32f4.peripherals;
const types = @import("regs/stm32f4.zig").types;
const Pin = @import("hal/pin.zig").Pin;

pub fn main() !void {
    var led = try Led.init("PC13");
    while (true) {
        delay(500);
        led.toggle();
    }
}

const Led = struct {
    state: bool,
    pin: Pin,

    pub fn init(name: []const u8) !@This() {
        var self = Led{ .state = false, .pin = try Pin.init(name) };
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
