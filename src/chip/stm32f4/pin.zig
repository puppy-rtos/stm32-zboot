const std = @import("std");
const regs = @import("regs.zig").devices.stm32f4.peripherals;
const GPIO_Type = @import("regs.zig").types.peripherals.GPIOA;
const RCC_Type = @import("regs.zig").types.peripherals.RCC;

const hal = @import("../../hal/hal.zig");
const PinType = hal.pin.PinType;
const Pin_Mode = hal.pin.Pin_Mode;
const Pin_Level = hal.pin.Pin_Level;

pub const ChipPinData = struct {
    port: *volatile GPIO_Type,
    pin: u8,
};

// pin set mode
fn set_mode(self: *const PinType, pin_mode: Pin_Mode) void {
    const port: *volatile GPIO_Type = @as(*volatile GPIO_Type, @ptrFromInt(self.data.port));
    const pin: u8 = self.data.pin;
    if (pin_mode == Pin_Mode.Output) {
        var moder_raw: u32 = port.MODER.raw; // todo .read()
        moder_raw = moder_raw & ~std.math.shl(u32, 0b11, pin * 2);
        moder_raw = moder_raw | std.math.shl(u32, 0b01, pin * 2);
        port.MODER.write_raw(moder_raw);
    } else if (pin_mode == Pin_Mode.Input) {
        var moder_raw: u32 = port.MODER.raw;
        moder_raw = moder_raw & ~std.math.shl(u32, 0b11, pin * 2);
        port.MODER.raw = moder_raw;
    }
}

// pin write
fn write(self: *const PinType, value: Pin_Level) void {
    const port: *volatile GPIO_Type = @as(*volatile GPIO_Type, @ptrFromInt(self.data.port));
    const pin: u8 = self.data.pin;
    if (value == Pin_Level.High) {
        port.ODR.raw = port.ODR.raw | std.math.shl(u32, 1, pin);
    } else {
        port.ODR.raw = port.ODR.raw & ~std.math.shl(u32, 1, pin);
    }
}

// pin read
fn read(self: *const PinType) Pin_Level {
    const port: *volatile GPIO_Type = @as(*volatile GPIO_Type, @ptrFromInt(self.data.port));
    const pin: u8 = self.data.pin;
    const idr_raw = port.IDR.raw;
    const pin_set = std.math.shl(u32, 1, pin);
    if (idr_raw & pin_set != 0) {
        return Pin_Level.High;
    } else {
        return Pin_Level.Low;
    }
}

const ops: hal.pin.PinOps = .{
    .mode = &set_mode,
    .write = &write,
    .read = &read,
};

pub fn init(name: []const u8) !PinType {
    // parse name
    const port_num = name[1] - 'A';
    const port_addr: u32 = @intFromPtr(regs.GPIOA) + 0x400 * @as(u32, port_num);
    const pin_num: u32 = try parseU32(name[2..]);

    const self: PinType = .{ .data = .{ .port = port_addr, .pin = @intCast(pin_num) }, .ops = &ops };

    const port = @as(*volatile GPIO_Type, @ptrFromInt(port_addr));
    const pin: u8 = @intCast(pin_num);

    // Enable PinX(A..) port
    var ahbenr_raw = regs.RCC.AHB1ENR.raw;
    ahbenr_raw = ahbenr_raw | std.math.shl(u32, 1, port_num);
    regs.RCC.AHB1ENR.raw = ahbenr_raw;
    // Enable PinX to output
    var moder_raw: u32 = port.MODER.raw;
    // todo: optimize
    moder_raw = moder_raw & ~std.math.shl(u32, 0b11, pin * 2);
    moder_raw = moder_raw | std.math.shl(u32, 0b01, pin * 2);
    port.MODER.raw = moder_raw;

    return self;
}

fn parseU32(input: []const u8) !u32 {
    var tmp: u32 = 0;
    for (input) |c| {
        if (c == 0) {
            break;
        }
        const digit = try std.fmt.charToDigit(c, 10);
        tmp = tmp * 10 + @as(u32, digit);
    }
    return tmp;
}
