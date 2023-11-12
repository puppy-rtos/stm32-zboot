// struct fal_partition
// {
//     uint32_t magic_word;

//     /* partition name */
//     char name[FAL_DEV_NAME_MAX];
//     /* flash device name for partition */
//     char flash_name[FAL_DEV_NAME_MAX];

//     /* partition offset address on flash device */
//     long offset;
//     size_t len;

//     uint32_t reserved;
// };

const FAL_MAGIC_WORD = 0x45503130;
const FAL_DEV_NAME_MAX = 24;
const Partition = packed struct {
    magic_word: u32,
    name1: u8,
    name2: u8,
    name3: u8,
    name4: u8,
    name5: u8,
    name6: u8,
    name7: u8,
    name8: u8,
    namex: u128,
    flash_name1: u8,
    flash_name2: u8,
    flash_name3: u8,
    flash_name4: u8,
    flash_name5: u8,
    flash_name6: u8,
    flash_name7: u8,
    flash_name8: u8,
    flash_namex: u128,
    offset: u32,
    len: u32,
    reserved: u32,
};

pub const default_partition: [2]Partition = .{ .{
    .magic_word = FAL_MAGIC_WORD,
    .name1 = 'b',
    .name2 = 'o',
    .name3 = 'o',
    .name4 = 't',
    .name5 = 0,
    .name6 = 0,
    .name7 = 0,
    .name8 = 0,
    .namex = 0,
    .flash_name1 = 'o',
    .flash_name2 = 'n',
    .flash_name3 = 'c',
    .flash_name4 = 'h',
    .flash_name5 = 'i',
    .flash_name6 = 'p',
    .flash_name7 = 0,
    .flash_name8 = 0,
    .flash_namex = 0,
    .offset = 0x00000000,
    .len = 0x00040000,
    .reserved = 0,
}, .{
    .magic_word = FAL_MAGIC_WORD,
    .name1 = 'a',
    .name2 = 'p',
    .name3 = 'p',
    .name4 = 0,
    .name5 = 0,
    .name6 = 0,
    .name7 = 0,
    .name8 = 0,
    .namex = 0,
    .flash_name1 = 'o',
    .flash_name2 = 'n',
    .flash_name3 = 'c',
    .flash_name4 = 'h',
    .flash_name5 = 'i',
    .flash_name6 = 'p',
    .flash_name7 = 0,
    .flash_name8 = 0,
    .flash_namex = 0,
    .offset = 0x00040000,
    .len = 0x00040000,
    .reserved = 0,
} };
