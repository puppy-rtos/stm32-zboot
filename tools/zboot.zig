/// zboot
/// Author:  @flyboy
///
const std = @import("std");
const mem = std.mem;

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

pub const default_partition: [3]Partition = .{ .{
    .magic_word = FAL_MAGIC_WORD,
    .name = .{ 'b', 'o', 'o', 't', 0, 0, 0, 0 },
    .flash_name = .{ 'o', 'n', 'c', 'h', 'i', 'p', 0, 0 },
    .offset = 0x00000000,
    .len = 0x00008000,
    .reserved = 0,
}, .{
    .magic_word = FAL_MAGIC_WORD,
    .name = .{ 'a', 'p', 'p', 0, 0, 0, 0, 0 },
    .flash_name = .{ 'o', 'n', 'c', 'h', 'i', 'p', 0, 0 },
    .offset = 0x00008000,
    .len = 0x00058000,
    .reserved = 0,
}, .{
    .magic_word = FAL_MAGIC_WORD,
    .name = .{ 's', 'w', 'a', 'p', 0, 0, 0, 0 },
    .flash_name = .{ 'o', 'n', 'c', 'h', 'i', 'p', 0, 0 },
    .offset = 0x00080000,
    .len = 0x00080000,
    .reserved = 0,
} };

const BUF_SIZE = 1024;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    std.debug.print("arg: {s},{d}\n", .{ args[1], args.len });

    var input_file: []u8 = undefined;
    if (args.len > 1) {
        input_file = args[1];
    } else {
        std.debug.print("{s}\n", .{"Usage: ./zboot xxx.bin"});
        return;
    }
    var file = try std.fs.cwd().openFile(input_file, .{});
    defer file.close();

    //open file and write bin data to rtthread.bin

    var file_name_buf: [512]u8 = undefined;
    var file_name = try std.fmt.bufPrint(&file_name_buf, "{s}_singed.bin", .{input_file});
    std.debug.print("=> {s}\n", .{file_name});
    const bin_file = try std.fs.cwd().createFile(file_name, .{});

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf_write = std.io.bufferedWriter(bin_file.writer());
    var out_stream = buf_write.writer();

    var out_file: std.fs.File = undefined;
    var read_buf: [BUF_SIZE]u8 = undefined;
    var out_buf: [BUF_SIZE]u8 = undefined;
    _ = out_buf;
    var offset: usize = 0;
    var write_offset: usize = 0;

    // read bin file and write to another file
    while (true) {
        const size = try in_stream.readAll(&read_buf);
        offset += size;

        std.debug.print("read: {d}, offset:{x}\n", .{ size, offset });

        const ret = try out_stream.write(read_buf[0..size]);
        write_offset += ret;

        std.debug.print("write: {d}, offset:{x}\n", .{ ret, write_offset });
        if (ret != size) {
            std.debug.print("write file error: {}\n", .{ret});
            return;
        }
        if (size < BUF_SIZE) {
            try buf_write.flush();
            break;
        }
    }

    // write partition data
    var slice = @as([*]u8, @ptrCast(@constCast(&default_partition)))[0..(@sizeOf(Partition) * 3)];

    const ret = try out_stream.write(slice);
    if (ret != slice.len) {
        std.debug.print("write file error: {d}\n", .{ret});
        return;
    }
    try buf_write.flush();
    bin_file.close();
    out_file.close();
}
