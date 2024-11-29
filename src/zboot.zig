/// zboot
/// Author:  @flyboy
///
const std = @import("std");
const mem = std.mem;
const json = std.json;

const Debug = false;
const KiB = 1024;

const ZC = @import("platform/sys.zig").zconfig;
const Part = @import("platform/fal/fal.zig").partition;

pub var partition_num: u32 = 0;
pub var default_partition: [Part.partition_table_MAX]Part.Partition = undefined;
pub var default_zconfig: ZC.ZbootConfig = undefined;

const JsonUart = struct {
    enable: u32,
    tx: []u8,
};

const JsonSpiFlash = struct {
    enable: u32,
    cs: []u8,
    sck: []u8,
    mosi: []u8,
    miso: []u8,
};

const JsonPartition = struct {
    name: []u8,
    flash_name: []u8,
    offset: u32,
    len: u32,
};

const JsonPartitionTable = struct {
    patition: []JsonPartition,
};

const JsonConfig = struct {
    uart: JsonUart,
    spiflash: JsonSpiFlash,
    partition_table: JsonPartitionTable,
};

const BUF_SIZE = 1024;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (Debug) {
        std.debug.print("arg: {s},{d}\n", .{ args[1], args.len });
    }

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
    const file_name = try std.fmt.bufPrint(&file_name_buf, "{s}_singed.bin", .{input_file});
    std.debug.print("=> {s}\n", .{file_name});
    const bin_file = try std.fs.cwd().createFile(file_name, .{});

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf_write = std.io.bufferedWriter(bin_file.writer());
    var out_stream = buf_write.writer();

    var read_buf: [BUF_SIZE]u8 = undefined;
    var magic_buf: [4]u8 = undefined;
    var offset: usize = 0;
    var write_offset: usize = 0;
    var magic_offset: usize = 0;

    // find magic word 'Z' 'B' 'O' 'T' 0x544F425A from tail of bin file
    const file_size = try file.getEndPos();
    if (Debug) {
        std.debug.print("file size: {d}\n", .{file_size});
    }
    try file.seekFromEnd(-@sizeOf(ZC.ZbootConfig));
    offset = file_size - @sizeOf(ZC.ZbootConfig);
    while (offset > 0) {
        const size = try file.readAll(&magic_buf);
        if (Debug) {
            std.debug.print("read: {d}\n", .{size});
        }
        if (size != 4) {
            std.debug.print("read file error: {d}\n", .{size});
            break;
        }
        if (magic_buf[0] == 0x5A and magic_buf[1] == 0x42 and magic_buf[2] == 0x4F and magic_buf[3] == 0x54) {
            magic_offset = offset;
            break;
        }
        try file.seekBy(-5);
        offset -= 1;
    }
    if (magic_offset == 0) {
        std.debug.print("can't find ZBOOT_CONFIG_MAGIC\n", .{});
        return;
    }

    try file.seekTo(0);
    offset = 0;

    // read bin file and write to another file
    while (true) {
        var size = try in_stream.readAll(&read_buf);
        offset += size;

        if (Debug) {
            std.debug.print("read: {d}, offset:{x}\n", .{ size, offset });
        }

        if (offset > magic_offset) {
            size = size - (offset - magic_offset);
        }

        const ret = try out_stream.write(read_buf[0..size]);
        write_offset += ret;

        if (Debug) {
            std.debug.print("write: {d}, offset:{x}\n", .{ ret, write_offset });
        }
        if (offset >= magic_offset) {
            break;
        }
        if (ret != size) {
            std.debug.print("write file error: {}\n", .{ret});
            return;
        }
        if (size < BUF_SIZE) {
            try buf_write.flush();
            break;
        }
    }
    // parse json file
    try json_parse();
    // write zbootconfig data
    default_zconfig.magic = ZC.ZBOOT_CONFIG_MAGIC;
    const slice_config = @as([*]u8, @ptrCast((&default_zconfig)))[0..(@sizeOf(ZC.ZbootConfig))];
    const ret_uart = try out_stream.write(slice_config);
    if (ret_uart != slice_config.len) {
        std.debug.print("write file error: {d}\n", .{ret_uart});
        return;
    }

    // write partition data
    const slice = @as([*]u8, @ptrCast((&default_partition)))[0..(@sizeOf(Part.Partition) * partition_num)];

    const ret = try out_stream.write(slice);
    if (ret != slice.len) {
        std.debug.print("write file error: {d}\n", .{ret});
        return;
    }
    try buf_write.flush();
    bin_file.close();
}

pub fn json_parse() !void {
    const allocator = std.heap.page_allocator;
    var buf: [4096]u8 = undefined;
    var file = try std.fs.cwd().openFile("config.json", .{});
    defer file.close();

    const size = try file.readAll(buf[0..]);

    if (Debug) {
        // dump the file contents
        std.debug.print("config.json: {s}\n", .{buf[0..size]});
    }
    const root = try std.json.parseFromSlice(JsonConfig, allocator, buf[0..size], .{ .allocate = .alloc_always });

    const json_config = root.value;

    // parse uart config
    if (Debug) {
        std.debug.print("uart enable:{d}\n", .{json_config.uart.enable});
        std.debug.print("uart tx:{s}\n", .{json_config.uart.tx});
    }
    if (json_config.uart.tx.len > ZC.PIN_NAME_MAX) {
        std.debug.print("uart tx is too long\n", .{});
        return;
    }
    if (json_config.uart.enable == 1) {
        default_zconfig.uart.enable = true;
    } else {
        default_zconfig.uart.enable = false;
    }
    mem.copyForwards(u8, &default_zconfig.uart.tx, json_config.uart.tx[0..json_config.uart.tx.len]);

    // parse spiflash config
    if (Debug) {
        std.debug.print("spi enable:{d}\n", .{json_config.spiflash.enable});
        std.debug.print("spi cs:{s}\n", .{json_config.spiflash.cs});
        std.debug.print("spi sck:{s}\n", .{json_config.spiflash.sck});
        std.debug.print("spi mosi:{s}\n", .{json_config.spiflash.mosi});
        std.debug.print("spi miso:{s}\n", .{json_config.spiflash.miso});
    }
    if (json_config.spiflash.enable == 1) {
        default_zconfig.spiflash.enable = true;
    } else {
        default_zconfig.spiflash.enable = false;
    }
    mem.copyForwards(u8, &default_zconfig.spiflash.cs, json_config.spiflash.cs[0..json_config.spiflash.cs.len]);
    mem.copyForwards(u8, &default_zconfig.spiflash.sck, json_config.spiflash.sck[0..json_config.spiflash.sck.len]);
    mem.copyForwards(u8, &default_zconfig.spiflash.mosi, json_config.spiflash.mosi[0..json_config.spiflash.mosi.len]);
    mem.copyForwards(u8, &default_zconfig.spiflash.miso, json_config.spiflash.miso[0..json_config.spiflash.miso.len]);

    // parse fal partition config
    for (json_config.partition_table.patition, 0..) |patition, i| {
        if (Debug) {
            std.debug.print("config.patition[{d}].name: {s}\n", .{ i, patition.name });
            std.debug.print("config.patition[{d}].flash_name: {s}\n", .{ i, patition.flash_name });
            std.debug.print("config.patition[{d}].offset: {d}\n", .{ i, patition.offset });
            std.debug.print("config.patition[{d}].len: {d}\n", .{ i, patition.len });
        }
        if (patition.flash_name.len > Part.FAL_DEV_NAME_MAX) {
            std.debug.print("flash_name is too long\n", .{});
            return;
        }
        if (patition.name.len > Part.FAL_DEV_NAME_MAX) {
            std.debug.print("name is too long\n", .{});
            return;
        }
        default_partition[i].magic_word = Part.FAL_MAGIC_WORD;
        mem.copyForwards(u8, &default_partition[i].name, patition.name[0..patition.name.len]);
        mem.copyForwards(u8, &default_partition[i].flash_name, patition.flash_name[0..patition.flash_name.len]);
        default_partition[i].offset = patition.offset * KiB;
        default_partition[i].len = patition.len * KiB;
        default_partition[i].reserved = 0;

        partition_num = @intCast(i + 1);
    }
}
