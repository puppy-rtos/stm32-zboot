const sys = @import("../sys.zig");
const mem = @import("std").mem;

const Debug: bool = false;

// flash err code
pub const FlashErr = enum(u8) {
    Ok = 0,
    Err = 1,
    OutOfBound = 2,
    Busy = 3,
    Transfer = 4,
    ErrRead = 5,
    ErrErase = 6,
    ErrWrite = 7,
};

pub const FlashOps = struct {
    // init the flash
    init: ?*const fn (self: *const Flash_Dev) FlashErr,
    // erase the flash block
    erase: ?*const fn (self: *const Flash_Dev, addr: u32, size: u32) FlashErr,
    // write the flash
    write: ?*const fn (self: *const Flash_Dev, addr: u32, data: []const u8) FlashErr,
    // read the flash
    read: *const fn (self: *const Flash_Dev, addr: u32, data: []u8) FlashErr,
};

pub const Flash_Dev = struct {
    name: []const u8,
    // flash device start address and len
    start: u32,
    len: u32,
    // the block size in the flash for erase minimum granularity
    blocks: [6]struct {
        // block size
        size: u32,
        // block count
        count: u32,
    },
    // write minimum granularity, unit: bit.
    //    1(nor flash)/ 8(stm32f2/f4)/ 32(stm32f1)/ 64(stm32l4)
    //    0 will not take effect.
    write_size: u32,
    // ops for flash
    ops: *const FlashOps,
    pub fn init(self: *const @This()) FlashErr {
        sys.debug.print("Flash[{s}]:init..\r\n", .{self.name}) catch {};
        var offset: u32 = 0;
        for (self.blocks, 0..) |b, i| {
            if (b.size == 0 or b.count == 0) {
                break;
            }
            sys.debug.print("Flash[{s}]:block[{d}]{x:0>8}-{x:0>8}:size:0x{x:0>6},count:{d:0>2}\r\n", .{ self.name, i, self.start + offset, self.start + offset + b.size * b.count, b.size, b.count }) catch {};
            offset = offset + b.size * b.count;
        }
        if (self.ops.init) |init_fn| {
            return init_fn(self);
        }
        return FlashErr.Ok;
    }
    pub fn erase(self: *const @This(), addr: u32, size: u32) FlashErr {
        if (Debug) {
            sys.debug.print("flash_earse:addr:0x{x},size:0x{x}\r\n", .{ addr, size }) catch {};
        }
        if (self.ops.erase) |erase_fn| {
            return erase_fn(self, addr, size);
        }
        return FlashErr.Ok;
    }
    pub fn write(self: *const @This(), addr: u32, data: []const u8) FlashErr {
        if (Debug) {
            sys.debug.print("flash_write:addr:0x{x}, data_ptr:0x{x}, size:{d} \r\n", .{ addr, @intFromPtr(data.ptr), data.len }) catch {};
            // dump data
            for (data, 0..) |*d, i| {
                if (i % 16 == 0) {
                    sys.debug.print("0x{x:0>8}:", .{addr + i}) catch {};
                }
                sys.debug.print(" {x:0>2}", .{d.*}) catch {};
                if (i % 16 == 15) {
                    sys.debug.print("\r\n", .{}) catch {};
                }
            }
            sys.debug.print("\r\n", .{}) catch {};
        }
        if (self.ops.write) |write_fn| {
            return write_fn(self, addr, data);
        }
        return FlashErr.Ok;
    }
    pub fn read(self: *const @This(), addr: u32, data: []u8) FlashErr {
        if (Debug) {
            sys.debug.print("flash_read:addr:0x{x}, data_ptr:0x{x}, size:{x}\r\n", .{ addr, @intFromPtr(data.ptr), data.len }) catch {};
        }
        const err = self.ops.read(self, addr, data);

        // dump data
        if (Debug) {
            for (data, 0..) |d, i| {
                if (i % 16 == 0) {
                    sys.debug.print("0x{x:0>8}:", .{addr + i}) catch {};
                }
                sys.debug.print(" {x:0>2}", .{d}) catch {};
                if (i % 16 == 15) {
                    sys.debug.print("\r\n", .{}) catch {};
                }
            }
            sys.debug.print("\r\n", .{}) catch {};
        }
        return err;
    }
};

// flash list
const flash_list: [2]*const Flash_Dev = .{
    &@import("../../hal/hal.zig").flash,
    &@import("../sfud/sfud.zig").flash.spi_flash,
};

//  flash find
pub fn find(name: []const u8) ?*const Flash_Dev {
    // find flash by name
    for (flash_list) |f| {
        if (mem.eql(u8, name[0..f.name.len], f.name[0..f.name.len])) {
            return f;
        }
    }

    return null;
}
