pub const PIN_NAME_MAX = 8;

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

// magic num
const ZBOOT_CONFIG_MAGIC = 0x5A424F54; // ZBOT

pub const ZbootConfig = extern struct {
    // magic num
    magic: u32,
    uart: UartConfig,
    spiflash: SpiFlashConfig,
};

// default config
var zboot_config = ZbootConfig{
    .magic = ZBOOT_CONFIG_MAGIC,
    .uart = UartConfig{
        .enable = true,
        .tx = .{ 'P', 'A', '9', 0, 0, 0, 0, 0 },
    },
    .spiflash = SpiFlashConfig{
        .enable = true,
        .cs = .{ 'P', 'B', '1', '2', 0, 0, 0, 0 },
        .sck = .{ 'P', 'B', '1', '3', 0, 0, 0, 0 },
        .mosi = .{ 'P', 'C', '3', 0, 0, 0, 0, 0 },
        .miso = .{ 'P', 'C', '2', 0, 0, 0, 0, 0 },
    },
};

// probe config from rom end
pub fn probe_extconfig(addr: u32) void {
    const extconfig: *ZbootConfig = @ptrFromInt(addr);
    if (extconfig.magic != ZBOOT_CONFIG_MAGIC) {
        return;
    }
    // copy config
    zboot_config = extconfig.*;
}

// get config
pub fn get_config() *ZbootConfig {
    return &zboot_config;
}
