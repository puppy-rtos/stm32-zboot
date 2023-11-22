/// zboot
/// Author:  @flyboy
///
const std = @import("std");
const mem = std.mem;
const json = std.json;

const Debug = false;

const FAL_MAGIC_WORD = 0x45503130;
const FAL_MAGIC_WORD_L = 0x3130;
const FAL_MAGIC_WORD_H = 0x4550;

const FAL_DEV_NAME_MAX = 8;
const partition_table_MAX = 8;

const Partition = extern struct {
    magic_word: u32,
    name: [FAL_DEV_NAME_MAX]u8,
    flash_name: [FAL_DEV_NAME_MAX]u8,
    offset: u32,
    len: u32,
    reserved: u32,
};

pub var partition_num: u32 = 0;
pub var default_partition: [partition_table_MAX]Partition = undefined;
pub var default_uart: UartConfig = undefined;

const PIN_NAME_MAX = 8;
pub const UartConfig = extern struct {
    enable: bool,
    tx: [PIN_NAME_MAX]u8,
};

const JsonUart = struct {
    enable: u32,
    tx: []u8,
};

const JsonPartition = struct {
    name: []u8,
    flash_name: []u8,
    offset: u32,
    len: u32,
};

const JsonPartitionTable = struct {
    num: u32,
    patition: []JsonPartition,
};

const JsonConfig = struct {
    uart: JsonUart,
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

        if (Debug) {
            std.debug.print("read: {d}, offset:{x}\n", .{ size, offset });
        }
        const ret = try out_stream.write(read_buf[0..size]);
        write_offset += ret;

        if (Debug) {
            std.debug.print("write: {d}, offset:{x}\n", .{ ret, write_offset });
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
    // write uart data
    var slice_uart = @as([*]u8, @ptrCast((&default_uart)))[0..(@sizeOf(UartConfig))];
    const ret_uart = try out_stream.write(slice_uart);
    if (ret_uart != slice_uart.len) {
        std.debug.print("write file error: {d}\n", .{ret_uart});
        return;
    }

    // write partition data
    var slice = @as([*]u8, @ptrCast((&default_partition)))[0..(@sizeOf(Partition) * partition_num)];

    const ret = try out_stream.write(slice);
    if (ret != slice.len) {
        std.debug.print("write file error: {d}\n", .{ret});
        return;
    }
    try buf_write.flush();
    bin_file.close();
    out_file.close();
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

    if (Debug) {
        std.debug.print("uart enable:{d}\n", .{json_config.uart.enable});
        std.debug.print("uart tx:{s}\n", .{json_config.uart.tx});
        std.debug.print("config.patition num: {d}\n", .{json_config.partition_table.num});
    }
    if (json_config.uart.tx.len > PIN_NAME_MAX) {
        std.debug.print("uart tx is too long\n", .{});
        return;
    }
    if (json_config.uart.enable == 1) {
        default_uart.enable = true;
    } else {
        default_uart.enable = false;
    }
    mem.copy(u8, &default_uart.tx, json_config.uart.tx[0..json_config.uart.tx.len]);
    partition_num = json_config.partition_table.num;
    var i: u32 = 0;
    while (i < json_config.partition_table.num) : (i += 1) {
        if (Debug) {
            std.debug.print("config.patition[{d}].name: {s}\n", .{ i, json_config.partition_table.patition[i].name });
            std.debug.print("config.patition[{d}].flash_name: {s}\n", .{ i, json_config.partition_table.patition[i].flash_name });
            std.debug.print("config.patition[{d}].offset: {d}\n", .{ i, json_config.partition_table.patition[i].offset });
            std.debug.print("config.patition[{d}].len: {d}\n", .{ i, json_config.partition_table.patition[i].len });
        }
        if (json_config.partition_table.patition[i].flash_name.len > FAL_DEV_NAME_MAX) {
            std.debug.print("flash_name is too long\n", .{});
            return;
        }
        if (json_config.partition_table.patition[i].name.len > FAL_DEV_NAME_MAX) {
            std.debug.print("name is too long\n", .{});
            return;
        }
        default_partition[i].magic_word = FAL_MAGIC_WORD;
        mem.copy(u8, &default_partition[i].name, json_config.partition_table.patition[i].name[0..json_config.partition_table.patition[i].name.len]);
        mem.copy(u8, &default_partition[i].flash_name, json_config.partition_table.patition[i].flash_name[0..json_config.partition_table.patition[i].flash_name.len]);
        default_partition[i].offset = json_config.partition_table.patition[i].offset;
        default_partition[i].len = json_config.partition_table.patition[i].len;
        default_partition[i].reserved = 0;
    }
}
