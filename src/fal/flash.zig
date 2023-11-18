const sys = @import("../sys.zig");

const Debug: bool = false;

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
    ops: struct {
        // init the flash
        init: *const fn (self: *const Flash_Dev) void,
        // erase the flash block
        erase: *const fn (self: *const Flash_Dev, addr: u32, size: u32) void,
        // write the flash
        write: *const fn (self: *const Flash_Dev, addr: u32, data: []const u8) void,
        // read the flash
        read: *const fn (self: *const Flash_Dev, addr: u32, data: []u8) void,
    },
    pub fn init(self: *const @This()) void {
        sys.debug.print("Flash[{s}]:init..\r\n", .{self.name}) catch {};
        var offset: u32 = 0;
        for (self.blocks, 0..) |b, i| {
            if (b.size == 0 or b.count == 0) {
                break;
            }
            sys.debug.print("Flash[{s}]:block[{d}]{x:0>4}-{x:0>4}:size:0x{x},count:{d}\r\n", .{ self.name, i, self.start + offset, self.start + offset + b.size * b.count, b.size, b.count }) catch {};
            offset = offset + b.size * b.count;
        }
        self.ops.init(self);
    }
    pub fn erase(self: *const @This(), addr: u32, size: u32) void {
        if (Debug) {
            sys.debug.print("flash_earse:addr:0x{x},size:0x{x}\r\n", .{ addr, size }) catch {};
        }
        self.ops.erase(self, addr, size);
    }
    pub fn write(self: *const @This(), addr: u32, data: []const u8) void {
        if (Debug) {
            sys.debug.print("flash_write:addr:0x{x}, data_ptr:0x{x}, size:{x} \r\n", .{ addr, @intFromPtr(data.ptr), data.len }) catch {};
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
        self.ops.write(self, addr, data);
    }
    pub fn read(self: *const @This(), addr: u32, data: []u8) void {
        if (Debug) {
            sys.debug.print("flash_read:addr:0x{x}, data_ptr:0x{x}, size:{x}\r\n", .{ addr, @intFromPtr(data.ptr), data.len }) catch {};
        }
        self.ops.read(self, addr, data);

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
    }
    // todo add iterator blocks
    pub fn iterator_block(self: *const @This(), func: fn (self: *const Flash_Dev, addr: u32, size: u32) void) void {
        _ = func;
        _ = self;
    }
};
