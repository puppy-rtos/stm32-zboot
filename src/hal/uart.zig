const std = @import("std");
const regs = @import("../regs/stm32f4.zig").devices.stm32f4.peripherals;
const types = @import("../regs/stm32f4.zig").types;
const clock = @import("clock.zig");
const Pin = @import("pin.zig").Pin;

const DEALY_US = 100;

// soft uart
const Uart = struct {
    tx: Pin,

    pub fn init(name: []const u8) !@This() {
        var self = Uart{ .tx = try Pin.init(name) };
        self.tx.set();
        clock.delay_us(DEALY_US);

        return self;
    }

    pub fn write(self: *const @This(), data: u8) void {
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

pub const InitError = error{
    InvalidBusFrequency,
    InvalidSpeed,
};
pub const WriteError = error{};
pub const ReadError = error{
    EndOfStream,
    TooFewBytesReceived,
    TooManyBytesReceived,
};

pub fn UartDebug() type {
    const SystemUart = Uart;
    return struct {
        const Self = @This();

        internal: SystemUart,

        /// Initializes the UART with the given config and returns a handle to the uart.
        pub fn init(name: []const u8) !Self {
            return Self{
                .internal = try SystemUart.init(name),
            };
        }

        pub fn reader(self: Self) Reader {
            return Reader{ .context = self };
        }

        pub fn writer(self: Self) Writer {
            return Writer{ .context = self };
        }

        pub const Reader = std.io.Reader(Self, ReadError, read_some);
        pub const Writer = std.io.Writer(Self, WriteError, write_some);

        fn read_some(self: Self, buffer: []u8) ReadError!usize {
            _ = self;
            for (buffer) |*c| {
                _ = c;
                // c.* = self.internal.rx();
            }
            return buffer.len;
        }
        fn write_some(self: Self, buffer: []const u8) WriteError!usize {
            for (buffer) |c| {
                self.internal.write(c);
            }
            return buffer.len;
        }
    };
}
