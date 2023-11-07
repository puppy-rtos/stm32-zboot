const std = @import("std");
const microzig = @import("microzig");
const regs = @import("regs/stm32f4.zig").devices.stm32f4.peripherals;
const types = @import("regs/stm32f4.zig").types;
const hal = @import("hal.zig");

pub fn main() !void {
    hal.clock.clock_init();
    const sysclk = hal.clock.get_sysfreq();

    var debug_writer = (try hal.uart.UartDebug().init("PA9")).writer();
    debug_writer.print("sysclk:{d}\r\n", .{sysclk}) catch {};

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
