const std = @import("std");

const hal = @import("../../hal/hal.zig");
const PinType = hal.pin.PinType;
const Pin_Mode = hal.pin.Pin_Mode;
const Pin_Level = hal.pin.Pin_Level;

const microzig = @import("microzig");
const regs = microzig.chip.peripherals;
const types = microzig.chip.types.peripherals;

pub const ChipPinData = struct {
    port: *volatile types.GPIOA,
    pin: u8,
};

// pin set mode
fn set_mode(self: *const PinType, pin_mode: Pin_Mode) void {
    const port: *volatile types.GPIOA = self.data.port;
    const pin: u8 = self.data.pin;
    if (pin_mode == Pin_Mode.Output) {
        var moder_raw: u32 = port.MODER.raw;
        moder_raw = moder_raw & ~std.math.shl(u32, 0b11, pin * 2);
        moder_raw = moder_raw | std.math.shl(u32, 0b01, pin * 2);
        port.MODER.raw = moder_raw;
    } else if (pin_mode == Pin_Mode.Input) {
        var moder_raw: u32 = port.MODER.raw;
        moder_raw = moder_raw & ~std.math.shl(u32, 0b11, pin * 2);
        port.MODER.raw = moder_raw;
    }
}

// pin write
fn write(self: *const PinType, value: Pin_Level) void {
    const port: *volatile types.GPIOA = self.data.port;
    const pin: u8 = self.data.pin;
    if (value == Pin_Level.High) {
        port.ODR.raw = port.ODR.raw | std.math.shl(u32, 1, pin);
    } else {
        port.ODR.raw = port.ODR.raw & ~std.math.shl(u32, 1, pin);
    }
}

// pin read
fn read(self: *const PinType) Pin_Level {
    const port: *volatile types.GPIOA = self.data.port;
    const pin: u8 = self.data.pin;
    var idr_raw = port.IDR.raw;
    var pin_set = std.math.shl(u32, 1, pin);
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
    var port_num = name[1] - 'A';
    var port_addr: u32 = @intFromPtr(regs.GPIOA) + 0x400 * @as(u32, port_num);
    var pin_num: u32 = try parseU32(name[2..]);

    var self: PinType = .{ .data = .{ .port = @as(*volatile types.GPIOA, @ptrFromInt(port_addr)), .pin = @intCast(pin_num) }, .ops = &ops };

    // Enable GPIOX(A..) port
    var ahbenr_raw = regs.RCC.AHB4ENR.raw;
    ahbenr_raw = ahbenr_raw | std.math.shl(u32, 1, port_num);
    regs.RCC.AHB4ENR.raw = ahbenr_raw;
    // Enable PinX to output
    var moder_raw: u32 = self.data.port.MODER.raw;
    // todo: optimize
    moder_raw = moder_raw & ~std.math.shl(u32, 0b11, self.data.pin * 2);
    moder_raw = moder_raw | std.math.shl(u32, 0b01, self.data.pin * 2);
    self.data.port.MODER.raw = moder_raw;

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
