const std = @import("std");

const chip_pin = @import("../chip/chip.zig").pin;

pub const Pin_Mode = enum { Input, Output };
pub const Pin_Level = enum { Low, High };

pub const PinOps = struct {
    // init the flash
    mode: *const fn (self: *const PinType, pin_mode: Pin_Mode) void,
    // write the flash
    write: *const fn (self: *const PinType, value: Pin_Level) void,
    // read the flash
    read: *const fn (self: *const PinType) Pin_Level,
};

pub const PinType = struct {
    data: chip_pin.ChipPinData,
    // ops for pin
    ops: *const PinOps,
    // set pin mode
    pub fn mode(self: *const @This(), pin_mode: Pin_Mode) void {
        self.ops.mode(self, pin_mode);
    }
    // write pin
    pub fn write(self: *const @This(), value: Pin_Level) void {
        self.ops.write(self, value);
    }
    // read pin
    pub fn read(self: *const @This()) Pin_Level {
        return self.ops.read(self);
    }
};

pub fn Pin(name: []const u8) !PinType {
    return chip_pin.init(name);
}
