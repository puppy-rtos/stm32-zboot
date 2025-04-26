const zconfig = @import("platform/sys.zig").zconfig;
const fal = @import("platform/fal/fal.zig");

const KiB = 1024;

// default config
pub const default_config = zconfig.ZbootConfig{
    .magic = zconfig.ZBOOT_CONFIG_MAGIC,
    .uart = zconfig.UartConfig{
        .enable = true,
        .tx = .{ 'P', 'A', '9', 0 },
    },
    .spiflash = zconfig.SpiFlashConfig{
        .enable = true,
        .cs = .{ 'P', 'B', '1', '2' },
        .sck = .{ 'P', 'B', '1', '3' },
        .mosi = .{ 'P', 'C', '3', 0 },
        .miso = .{ 'P', 'C', '2', 0 },
    },
};

// default Partition
pub const default_partition: [3]fal.partition.Partition = .{ .{
    .magic_word = fal.partition.FAL_MAGIC_WORD,
    .name = .{ 'b', 'o', 'o', 't', 0, 0, 0, 0 },
    .flash_name = .{ 'o', 'n', 'c', 'h', 'i', 'p', 0, 0 },
    .offset = 0x00000000,
    .len = 0x00008000,
    .reserved = 0,
}, .{
    .magic_word = fal.partition.FAL_MAGIC_WORD,
    .name = .{ 'a', 'p', 'p', 0, 0, 0, 0, 0 },
    .flash_name = .{ 'o', 'n', 'c', 'h', 'i', 'p', 0, 0 },
    .offset = 0x00008000,
    .len = 0x00038000,
    .reserved = 0,
}, .{
    .magic_word = fal.partition.FAL_MAGIC_WORD,
    .name = .{ 's', 'w', 'a', 'p', 0, 0, 0, 0 },
    .flash_name = .{ 'o', 'n', 'c', 'h', 'i', 'p', 0, 0 },
    .offset = 0x00040000,
    .len = 0x00020000,
    .reserved = 0,
} };

comptime {

    @export(&default_config, .{
        .name = "default_config",
        .linkage = .strong,
        .section = "dconfig",
        .visibility = .default,
    });

    @export(&default_partition, .{
        .name = "default_partition",
        .linkage = .strong,
        .section = "fal",
        .visibility = .default,
    });
}
