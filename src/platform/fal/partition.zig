const mem = @import("std").mem;
const sys = @import("../sys.zig");
const hal = @import("../../hal/hal.zig");
const fal = @import("fal.zig");

pub const FAL_MAGIC_WORD = 0x45503130;
const FAL_MAGIC_WORD_L = 0x3130;
const FAL_MAGIC_WORD_H = 0x4550;

pub const partition_table_MAX = 8;
const FAL_PATITION_SIZE_MAX = @sizeOf(Partition) * partition_table_MAX;
pub const FAL_DEV_NAME_MAX = 8;

pub const Partition = extern struct {
    magic_word: u32,
    name: [FAL_DEV_NAME_MAX]u8,
    flash_name: [FAL_DEV_NAME_MAX]u8,
    offset: u32,
    len: u32,
    reserved: u32,
};

const FalPartition = struct {
    num: u32,
    partition: [partition_table_MAX]Partition,
};
pub var partition_table: FalPartition = .{ .num = 0, .partition = undefined };

const dconfig = @import("../../default_config.zig");

comptime {
    const export_opts = .{
        .name = "default_partition",
        .section = "fal",
        .linkage = .Strong,
    };
    @export(dconfig.default_partition, export_opts);
}

pub fn find(name: []const u8) ?*const Partition {
    var i: u32 = 0;
    while (i < partition_table.num) : (i += 1) {
        const partition = &partition_table.partition[i];
        if (mem.eql(u8, name, partition.name[0..name.len])) {
            return partition;
        }
    }
    return null;
}

// partition init
// find flash flash, init partition_table
pub fn init(start_offset: u32) void {
    const flash = fal.flash.find("onchip").?;

    // find magic word
    var magic_word: u32 = 0;
    var slice = @as([*]u8, @ptrCast(&magic_word))[0..(@sizeOf(u32))];
    var partition_start: u32 = start_offset;
    var part_is_find: bool = false;
    while (partition_start < start_offset + FAL_PATITION_SIZE_MAX) : (partition_start += 1) {
        _ = flash.read(partition_start, slice);
        if (magic_word == FAL_MAGIC_WORD) {
            part_is_find = true;
            sys.debug.print("partition table find at 0x{x}\r\n", .{partition_start}) catch {};
            break;
        }
    }
    partition_table.num = 0;
    // load partition
    while (part_is_find) {
        var part_new = @as([*]u8, @ptrCast(&partition_table.partition[partition_table.num]))[0..(@sizeOf(Partition))];

        _ = flash.read(partition_start, part_new);
        // check magic word
        if (partition_table.partition[partition_table.num].magic_word != FAL_MAGIC_WORD) {
            break;
        }
        // check partition flash
        const new_flash = fal.flash.find(partition_table.partition[partition_table.num].flash_name[0..]);
        if (new_flash == null) {
            sys.debug.print("flash {s} not find\r\n", .{partition_table.partition[partition_table.num].flash_name}) catch {};
        }

        partition_table.num += 1;
        partition_start += @sizeOf(Partition);
    }
}
// print the partition table
pub fn print() void {
    var i: u32 = 0;
    while (i < partition_table.num) {
        const partition = &partition_table.partition[i];
        sys.debug.print("partition: {d}, name: {s}, flash_name: {s}, offset: {x}, len: {x}\r\n", .{ i, partition.name, partition.flash_name, partition.offset, partition.len }) catch {};
        i += 1;
    }
}

// partition erase
pub fn erase(partition: *const Partition, offset: u32, len: u32) void {
    const flash = fal.flash.find(partition.flash_name[0..]).?;
    _ = flash.erase(flash.start + partition.offset + offset, len);
}

// partition write
pub fn write(partition: *const Partition, offset: u32, data: []const u8) void {
    const flash = fal.flash.find(partition.flash_name[0..]).?;
    _ = flash.write(flash.start + partition.offset + offset, data);
}

// partition read
pub fn read(partition: *const Partition, offset: u32, data: []u8) void {
    const flash = fal.flash.find(partition.flash_name[0..]).?;
    _ = flash.read(flash.start + partition.offset + offset, data);
}
