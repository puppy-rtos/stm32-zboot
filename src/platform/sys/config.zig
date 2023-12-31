pub const PIN_NAME_MAX = 8;
// magic num
pub const ZBOOT_CONFIG_MAGIC = 0x5A424F54; // ZBOT

pub const ChipFlashConfig = extern struct {
    size: u32,
};

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
    chipflash: ChipFlashConfig,
    uart: UartConfig,
    spiflash: SpiFlashConfig,
};

const dconfig = @import("../../default_config.zig");

// probe config from rom end
pub fn probe_extconfig(addr: u32) void {
    const extconfig: *ZbootConfig = @ptrFromInt(addr);
    if (extconfig.magic != ZBOOT_CONFIG_MAGIC) {
        return;
    }
    // copy config
    dconfig.default_config = extconfig.*;
}

// get config
pub fn get_config() *ZbootConfig {
    return &dconfig.default_config;
}
