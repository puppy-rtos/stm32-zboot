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
        self.ops.init(self);
    }
    pub fn erase(self: *const @This(), addr: u32, size: u32) void {
        self.ops.erase(self, addr, size);
    }
    pub fn write(self: *const @This(), addr: u32, data: []const u8) void {
        self.ops.write(self, addr, data);
    }
    pub fn read(self: *const @This(), addr: u32, data: []u8) void {
        self.ops.read(self, addr, data);
    }
};
