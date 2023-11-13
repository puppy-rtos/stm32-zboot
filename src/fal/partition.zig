const FAL_MAGIC_WORD = 0x45503130;
const FAL_MAGIC_WORD_L = 0x3130;
const FAL_MAGIC_WORD_H = 0x4550;

const FAL_DEV_NAME_MAX = 8;

const Partition = extern struct {
    magic_word: u32,
    name: [FAL_DEV_NAME_MAX]u8,
    flash_name: [FAL_DEV_NAME_MAX]u8,
    offset: u32,
    len: u32,
    reserved: u32,
};

pub const default_partition: [2]Partition = .{ .{
    .magic_word = FAL_MAGIC_WORD,
    .name = .{ 'b', 'o', 'o', 't', 0, 0, 0, 0 },
    .flash_name = .{ 'o', 'n', 'c', 'h', 'i', 'p', 0, 0 },
    .offset = 0x00000000,
    .len = 0x00040000,
    .reserved = 0,
}, .{
    .magic_word = FAL_MAGIC_WORD,
    .name = .{ 'a', 'p', 'p', 0, 0, 0, 0, 0 },
    .flash_name = .{ 'o', 'n', 'c', 'h', 'i', 'p', 0, 0 },
    .offset = 0x00040000,
    .len = 0x00040000,
    .reserved = 0,
} };

comptime {
    const export_opts = .{
        .name = "default_partition",
        .section = "fal",
        .linkage = .Strong,
    };
    @export(default_partition, export_opts);
}
