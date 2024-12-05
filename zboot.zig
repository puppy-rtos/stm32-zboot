/// zboot
/// Author:  @flyboy
///
const std = @import("std");
const mem = std.mem;
const json = std.json;

const Debug = false;
const KiB = 1024;

const ZC = @import("src/platform/sys.zig").zconfig;
const Part = @import("src/platform/fal/fal.zig").partition;
const OTA = @import("src/platform/ota/ota.zig");

const stm32zboot = @embedFile("stm32-zboot");
const stm32app = @embedFile("stm32-app");
const configjson = @embedFile("config.json");

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

fn help() void {
    std.debug.print("Usage: \n", .{});
    std.debug.print("  zboot boot: gen stm32-zboot.bin [config.json] \n", .{});
    std.debug.print("  zboot app:  gen stm32-app.bin \n", .{});
    std.debug.print("  zboot rbl <xxx.bin> <version>: tar xxx.bin to xxx.rbl \n", .{});
    // std.debug.print("  zboot allbin: tar stm32-zboot|app|[swap] to all.bin \n", .{});
}

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
        // if argv[1] == boot gen stm32-zboot.bin
        if (mem.eql(u8, args[1], "boot")) {
            // if config.json not exist, gen config.json
            std.fs.cwd().access("config.json", .{}) catch {
                std.debug.print("=> gen config.json\n", .{});
                try gen_configjson();
            };
            std.debug.print("=> gen stm32-zboot.bin\n", .{});
            try gen_boot();
            return;
        } else if (mem.eql(u8, args[1], "rbl")) {
            if (args.len < 3) {
                help();
                return;
            }
            input_file = args[2];
            try gen_rbl(input_file, args[3]);
            return;
        } else if (mem.eql(u8, args[1], "app")) {
            try gen_app();
            std.debug.print("=> gen stm32-app.bin\n", .{});
            return;
        }
    } else {
        help();
        return;
    }
}

fn gen_configjson() !void {
    const bin_file = try std.fs.cwd().createFile("./config.json", .{});

    var buf_write = std.io.bufferedWriter(bin_file.writer());
    var out_stream = buf_write.writer();

    _ = out_stream.write(configjson) catch {
        std.debug.print("write file error\n", .{});
        return;
    };
    try buf_write.flush();
    bin_file.close();
}

fn gen_boot() !void {
    const bin_file = try std.fs.cwd().createFile("./stm32-zboot.bin", .{});

    var buf_write = std.io.bufferedWriter(bin_file.writer());
    var out_stream = buf_write.writer();

    // find magic word 'Z' 'B' 'O' 'T' 0x544F425A from tail of bin file
    var magic_offset: usize = 0;
    var offset = stm32zboot.len - @sizeOf(ZC.ZbootConfig);
    while (offset > 0) {
        const magic_buf = stm32zboot[offset..(offset + 4)];
        if (magic_buf[0] == 0x5A and magic_buf[1] == 0x42 and magic_buf[2] == 0x4F and magic_buf[3] == 0x54) {
            magic_offset = offset;
            break;
        }
        offset -= 1;
    }
    if (magic_offset == 0) {
        std.debug.print("can't find ZBOOT_CONFIG_MAGIC\n", .{});
        return;
    }

    _ = out_stream.write(stm32zboot[0..magic_offset]) catch {
        std.debug.print("write file error\n", .{});
        return;
    };

    // parse json file
    try json_parse("config.json");
    // write zbootconfig data
    default_zconfig.magic = ZC.ZBOOT_CONFIG_MAGIC;
    const slice_config = @as([*]u8, @ptrCast((&default_zconfig)))[0..(@sizeOf(ZC.ZbootConfig))];
    _ = out_stream.write(slice_config) catch {
        std.debug.print("write file error\n", .{});
        return;
    };

    // write partition data
    const slice = @as([*]u8, @ptrCast((&default_partition)))[0..(@sizeOf(Part.Partition) * partition_num)];
    _ = out_stream.write(slice) catch {
        std.debug.print("write file error\n", .{});
        return;
    };
    try buf_write.flush();
    bin_file.close();
}

fn gen_app() !void {
    const bin_file = try std.fs.cwd().createFile("./stm32-app.bin", .{});

    var buf_write = std.io.bufferedWriter(bin_file.writer());
    var out_stream = buf_write.writer();

    // find magic word 'Z' 'B' 'O' 'T' 0x544F425A from tail of bin file
    var magic_offset: usize = 0;
    var offset = stm32app.len - @sizeOf(ZC.ZbootConfig);
    while (offset > 0) {
        const magic_buf = stm32app[offset..(offset + 4)];
        if (magic_buf[0] == 0x5A and magic_buf[1] == 0x42 and magic_buf[2] == 0x4F and magic_buf[3] == 0x54) {
            magic_offset = offset;
            break;
        }
        offset -= 1;
    }
    if (magic_offset == 0) {
        std.debug.print("can't find ZBOOT_CONFIG_MAGIC\n", .{});
        return;
    }

    _ = out_stream.write(stm32app[0..magic_offset]) catch {
        std.debug.print("write file error\n", .{});
        return;
    };

    // parse json file
    try json_parse("config.json");
    // write zbootconfig data
    default_zconfig.magic = ZC.ZBOOT_CONFIG_MAGIC;
    const slice_config = @as([*]u8, @ptrCast((&default_zconfig)))[0..(@sizeOf(ZC.ZbootConfig))];
    _ = out_stream.write(slice_config) catch {
        std.debug.print("write file error\n", .{});
        return;
    };

    try buf_write.flush();
    bin_file.close();
}

const FLZ_BUF_SIZE = 4096;
const TEMP_FILE = "_crom_tmp.tmp";

fn gen_rbl(input_file: []u8, version: []u8) !void {
    var file = try std.fs.cwd().openFile(input_file, .{});
    defer file.close();

    // ready ota header
    var fw_info: OTA.Ota_FW_Info = .{
        .magic = .{ 'R', 'B', 'L', 0 },
        .algo = .FASTLZ,
        .algo2 = .NONE,
        .time_stamp = 0,
        .name = .{ 'a', 'p', 'p' } ++ .{0} ** 13,
        .version = .{0} ** 24,
        .sn = .{'0'} ** 24,
        .body_crc = 0,
        .hash_code = 0,
        .raw_size = 0,
        .pkg_size = 0,
        .hdr_crc = 0,
    };

    const file_size = try file.getEndPos();
    mem.copyForwards(u8, &fw_info.version, version[0..version.len]);
    fw_info.raw_size = @intCast(file_size);
    fw_info.time_stamp = @intCast(std.time.milliTimestamp());

    // body crc
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [FLZ_BUF_SIZE]u8 = undefined;
    var crc: u32 = 0;
    var hash: u32 = OTA.ZBOOT_HASH_FNV_SEED;

    const crom_file = try std.fs.cwd().createFile(TEMP_FILE, .{});

    while (true) {
        const size = try in_stream.read(buf[0..]);
        if (size == 0) {
            break;
        }
        hash = OTA.calc_hash(hash, buf[0..size]);
        var crom_buf: [FLZ_BUF_SIZE + OTA.fastlz_buffer_padding(FLZ_BUF_SIZE)]u8 = undefined;
        for (&crom_buf) |*b| {
            b.* = 0;
        }
        const compress_size = OTA.fastlz1_compress(crom_buf[0..], buf[0..size]);
        const buffer_hdr: [4]u8 = .{
            @intCast(compress_size / (1 << 24)),
            @intCast((compress_size % (1 << 24)) / (1 << 16)),
            @intCast((compress_size % (1 << 16)) / (1 << 8)),
            @intCast(compress_size % (1 << 8)),
        };
        _ = crom_file.writeAll(buffer_hdr[0..]) catch {
            std.debug.print("write file error\n", .{});
            return;
        };
        _ = crom_file.writeAll(crom_buf[0..compress_size]) catch {
            std.debug.print("write crom file error\n", .{});
            return;
        };

        crc = OTA.crc32(crc, buffer_hdr[0..]);
        crc = OTA.crc32(crc, crom_buf[0..compress_size]);
        if (size < 1024) {
            break;
        }
    }
    crom_file.close();

    // write rbl file
    file = try std.fs.cwd().openFile(TEMP_FILE, .{});
    buf_reader = std.io.bufferedReader(file.reader());
    in_stream = buf_reader.reader();

    var file_name_buf: [512]u8 = undefined;
    const file_name = try std.fmt.bufPrint(&file_name_buf, "{s}.rbl", .{input_file});
    std.debug.print("=> {s}\n", .{file_name});
    const bin_file = try std.fs.cwd().createFile(file_name, .{});

    var buf_write = std.io.bufferedWriter(bin_file.writer());
    var out_stream = buf_write.writer();

    var read_buf: [BUF_SIZE]u8 = undefined;
    var offset: usize = 0;
    var write_offset: usize = 0;

    // write ota header

    fw_info.body_crc = crc;
    fw_info.hash_code = hash;
    fw_info.pkg_size = @intCast(try file.getEndPos());
    fw_info.hdr_crc = OTA.crc32(0, @as([*]u8, @ptrCast(&fw_info))[0..(@sizeOf(OTA.Ota_FW_Info) - @sizeOf(u32))]);
    if (Debug) {
        std.debug.print("crc: {x}, hash: {x}\n", .{ crc, hash });
        std.debug.print("hdr_crc: {x}\n", .{fw_info.hdr_crc});
    }
    const slice_ota = @as([*]u8, @ptrCast((&fw_info)))[0..(@sizeOf(OTA.Ota_FW_Info))];
    _ = out_stream.write(slice_ota) catch {
        std.debug.print("write file error\n", .{});
        return;
    };

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

    try buf_write.flush();
    bin_file.close();
    // delete crom file
    try std.fs.cwd().deleteFile(TEMP_FILE);
}

pub fn json_parse(config_file: []const u8) !void {
    const allocator = std.heap.page_allocator;
    var buf: [4096]u8 = undefined;
    var file = try std.fs.cwd().openFile(config_file, .{});
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
