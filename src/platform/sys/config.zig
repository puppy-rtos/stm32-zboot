pub const PIN_NAME_MAX = 4;
// magic num
pub const ZBOOT_CONFIG_MAGIC = 0x544F425A; // TOBZ --> ZBOT

pub const UartConfig = extern struct {
    enable: bool,
    tx: [PIN_NAME_MAX]u8,
};

// spi flash config
pub const SpiFlashConfig = extern struct {
    enable: bool,
    cs: [PIN_NAME_MAX]u8,
    sck: [PIN_NAME_MAX]u8,
    mosi: [PIN_NAME_MAX]u8,
    miso: [PIN_NAME_MAX]u8,
};

pub const ZbootConfig = extern struct {
    // magic num
    magic: u32,
    uart: UartConfig,
    spiflash: SpiFlashConfig,
};

const dconfig = @import("../../default_config.zig");
var zboot_config: *const ZbootConfig = &dconfig.default_config;

// probe config from rom end
pub fn probe_extconfig(addr: u32) void {
    var align_addr: u32 = (addr + 3) & ~@as(u32, 3); // Align to 4 bytes
    const end_addr = addr + 0x1000;

    while (align_addr <= end_addr) {
        const magic_word: *u32 = @ptrFromInt(align_addr);
        if (magic_word.* == ZBOOT_CONFIG_MAGIC) {
            const extconfig: *ZbootConfig = @ptrFromInt(align_addr);
            zboot_config = extconfig;
            return;
        }
        align_addr += 4;
    }
}

// get config
pub fn get_config() *const ZbootConfig {
    return zboot_config;
}
