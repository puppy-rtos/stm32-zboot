const std = @import("std");
const microzig = @import("microzig");
const regs = @import("regs/stm32f4.zig").devices.stm32f4.peripherals;
const types = @import("regs/stm32f4.zig").types;
const Pin = @import("hal/pin.zig").Pin;
const clock = @import("hal/clock.zig");

pub fn main() !void {
    clock.clock_init();
    const sysclk = clock.get_sysfreq();
    _ = sysclk;
    var led = try Led.init("PC13");
    var uart = try Uart.init("PA9");

    while (true) {
        uart.write('A');
        led.toggle();
        clock.delay_ms(1000);
    }
}

const DEALY_US = 90;

// soft uart
const Uart = struct {
    tx: Pin,

    pub fn init(name: []const u8) !@This() {
        var self = Uart{ .tx = try Pin.init(name) };
        self.tx.set();
        clock.delay_us(DEALY_US);

        return self;
    }

    pub fn write(self: *@This(), data: u8) void {
        var i: u8 = 0;
        var mask: u8 = 0x01;

        // start bit
        self.tx.clear();
        clock.delay_us(DEALY_US);

        // send data
        while (i < 8) {
            if ((data & mask) == mask) {
                self.tx.set();
            } else {
                self.tx.clear();
            }
            clock.delay_us(DEALY_US);
            mask <<= 1;
            i += 1;
        }

        // stop bit
        self.tx.set();
        clock.delay_us(DEALY_US);
    }
};

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
