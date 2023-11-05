const std = @import("std");
const regs = @import("../regs/stm32f4.zig").devices.stm32f4.peripherals;
const types = @import("../regs/stm32f4.zig").types;

pub const Pin = struct {
    port: *volatile types.peripherals.GPIOA,
    pin: u8,

    pub fn init(name: []const u8) !@This() {
        // parse name
        var port_num = name[1] - 'A';
        var port_addr: u32 = 0x40020000 + 0x400 * @as(u32, port_num);
        var pin_num: u32 = try parseU32(name[2..]);

        var self: Pin = Pin{ .port = @as(*volatile types.peripherals.GPIOA, @ptrFromInt(port_addr)), .pin = @intCast(pin_num) };

        // Enable GPIOX(A..) port
        var ahb1enr_raw = regs.RCC.AHB1ENR.raw;
        ahb1enr_raw = ahb1enr_raw | std.math.shl(u32, 1, port_num);
        regs.RCC.AHB1ENR.raw = ahb1enr_raw;
        // Enable PinX to output
        var moder_raw: u32 = self.port.MODER.raw;
        // todo: optimize
        moder_raw = moder_raw & ~std.math.shl(u32, 0b11, self.pin * 2);
        moder_raw = moder_raw | std.math.shl(u32, 0b01, self.pin * 2);
        self.port.MODER.raw = moder_raw;

        return self;
    }

    pub fn set(self: *@This()) void {
        const pin_set = std.math.shl(u32, 1, self.pin);
        self.port.ODR.raw = self.port.ODR.raw | pin_set;
    }

    pub fn clear(self: *@This()) void {
        const pin_set = std.math.shl(u32, 1, self.pin);
        self.port.ODR.raw = self.port.ODR.raw & ~pin_set;
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
