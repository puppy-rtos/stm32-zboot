pub const Flash_Dev = struct {
    name: []const u8,
    // flash device start address and len
    start: u32,
    len: u32,
    // the block size in the flash for erase minimum granularity
    block_size: u32,
    // write minimum granularity, unit: bit.
    //    1(nor flash)/ 8(stm32f2/f4)/ 32(stm32f1)/ 64(stm32l4)
    //    0 will not take effect.
    write_size: u32,
    // ops for flash
    ops: struct {
        // init the flash
        init: *const fn () void,
        // erase the flash block
        erase: *const fn (addr: u32, size: u32) void,
        // write the flash
        write: *const fn (addr: u32, data: []const u8, size: u32) void,
        // read the flash
        read: *const fn (addr: u32, data: []u8, size: u32) void,
    },
    pub fn init(self: *const @This()) void {
        self.ops.init();
    }
    pub fn erase(self: *const @This(), addr: u32, size: u32) void {
        self.ops.erase(addr, size);
    }
    pub fn write(self: *const @This(), addr: u32, data: []const u8, size: u32) void {
        self.ops.write(addr, data, size);
    }
    pub fn read(self: *const @This(), addr: u32, data: []u8, size: u32) void {
        self.ops.read(addr, data, size);
    }
};
