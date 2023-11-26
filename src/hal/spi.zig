const std = @import("std");

const hal = @import("hal.zig");
const sys = @import("../platform/sys.zig");

pub const Spi_Mode = enum { Input, Output };
pub const Spi_Level = enum { Low, High };

pub const SpiOps = struct {
    // write and read
    wr: *const fn (self: *const SpiType, write_buf: ?[]const u8, read_buf: ?[]u8) bool,
};

pub const SpiType = struct {
    // spi pin
    mosi: hal.pin.PinType,
    miso: hal.pin.PinType,
    sck: hal.pin.PinType,
    cs: hal.pin.PinType,
    // ops for pin
    ops: *const SpiOps,
    // write and read
    pub fn wr(self: *const @This(), write_buf: ?[]const u8, read_buf: ?[]u8) bool {
        return self.ops.wr(self, write_buf, read_buf);
    }
};

// write and read one byte
fn wr_byte(self: *const SpiType, write_byte: u8) u8 {
    var i: u8 = 0;
    var read_byte: u8 = 0;
    while (i < 8) : (i += 1) {
        if (write_byte & (std.math.shr(u8, 0x80, i)) != 0) {
            self.mosi.write(hal.pin.Pin_Level.High);
        } else {
            self.mosi.write(hal.pin.Pin_Level.Low);
        }
        self.sck.write(hal.pin.Pin_Level.High);

        if (self.miso.read() == hal.pin.Pin_Level.High) {
            read_byte |= (std.math.shr(u8, 0x80, i));
        }

        self.sck.write(hal.pin.Pin_Level.Low);
    }
    return read_byte;
}

pub fn wr(self: *const SpiType, write_buf: ?[]const u8, read_buf: ?[]u8) bool {
    // start transfer
    self.cs.write(hal.pin.Pin_Level.Low);

    // write then read
    if (write_buf != null) {
        const write_pos = write_buf.?;
        for (write_pos) |byte| {
            _ = wr_byte(self, byte);
        }
    }
    if (read_buf != null) {
        const read_pos = read_buf.?;
        var i: usize = 0;
        while (i < read_pos.len) : (i += 1) {
            read_pos[i] = wr_byte(self, 0xFF);
        }
    }
    // end transfer
    self.cs.write(hal.pin.Pin_Level.High);

    return true;
}
const ops: SpiOps = .{
    .wr = &wr,
};

pub fn Spi(mosi: []const u8, miso: []const u8, sck: []const u8, cs: []const u8) !SpiType {
    const self: SpiType = SpiType{
        .mosi = try hal.pin.Pin(mosi),
        .miso = try hal.pin.Pin(miso),
        .sck = try hal.pin.Pin(sck),
        .cs = try hal.pin.Pin(cs),
        .ops = &ops,
    };
    self.miso.mode(hal.pin.Pin_Mode.Input);

    self.cs.write(hal.pin.Pin_Level.High);
    self.sck.write(hal.pin.Pin_Level.Low);
    return self;
}
