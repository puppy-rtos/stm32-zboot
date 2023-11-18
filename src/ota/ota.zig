const sys = @import("../sys.zig");
const fal_partition = @import("../fal/partition.zig");
const hal = @import("../hal.zig");

const mem = @import("std").mem;

// ota header
pub const Ota_FW_Info = extern struct {
    magic: [4]u8,
    algo: Ota_Algo,
    algo2: Ota_Algo,
    time_stamp: u32,
    name: [16]u8,
    version: [24]u8,
    sn: [24]u8,
    body_crc: u32,
    hash_code: u32,
    raw_size: u32,
    pkg_size: u32,
    hdr_crc: u32,
};

// zboot algo
pub const Ota_Algo = enum(u16) {
    NONE = 0x0,
    XOR = 0x1,
    AES256 = 0x2,

    GZIP = 0x100,
    QUICKLZ = 0x200,
    FASTLZ = 0x300,

    CRYPT_STAT_MASK = 0xF,
    CMPRS_STAT_MASK = 0xF00,
};

// print ota header
pub fn fw_info_print(fw_info: *const volatile Ota_FW_Info) void {
    // check ota_fw_info
    if (fw_info.magic[0] != 'R' or fw_info.magic[1] != 'B' or fw_info.magic[2] != 'L') {
        sys.debug.print("magic not match\r\n", .{}) catch {};
        return;
    }
    sys.debug.print("magic:{s}\r\n", .{fw_info.magic}) catch {};
    switch (fw_info.algo) {
        Ota_Algo.NONE => sys.debug.writeAll("algo:NONE\r\n") catch {},
        Ota_Algo.XOR => sys.debug.writeAll("algo:XOR\r\n") catch {},
        Ota_Algo.AES256 => sys.debug.writeAll("algo:AES256\r\n") catch {},
        else => sys.debug.writeAll("algo:unknown\r\n") catch {},
    }
    switch (fw_info.algo2) {
        Ota_Algo.NONE => sys.debug.writeAll("algo2:NONE\r\n") catch {},
        Ota_Algo.XOR => sys.debug.writeAll("algo2:XOR\r\n") catch {},
        Ota_Algo.AES256 => sys.debug.writeAll("algo2:AES256\r\n") catch {},
        else => sys.debug.writeAll("algo2:unknown\r\n") catch {},
    }
    sys.debug.print("time_stamp:{d}\r\n", .{fw_info.time_stamp}) catch {};
    sys.debug.print("name:{s}\r\n", .{fw_info.name}) catch {};
    sys.debug.print("version:{s}\r\n", .{fw_info.version}) catch {};
    sys.debug.print("sn:{s}\r\n", .{fw_info.sn}) catch {};
    sys.debug.print("body_crc:{x}\r\n", .{fw_info.body_crc}) catch {};
    sys.debug.print("hash_code:{x}\r\n", .{fw_info.hash_code}) catch {};
    sys.debug.print("raw_size:{d}\r\n", .{fw_info.raw_size}) catch {};
    sys.debug.print("pkg_size:{d}\r\n", .{fw_info.pkg_size}) catch {};
    sys.debug.print("hdr_crc:{x}\r\n", .{fw_info.hdr_crc}) catch {};
}

fn strlen(str: []const u8) u32 {
    var i: u32 = 0;
    while (str[i] != 0) : (i += 1) {}
    return i;
}

// ota swap: move swap to target partition
pub fn swap() void {
    const flash1 = hal.chip_flash.chip_flash;
    const part1 = fal_partition.partition_find("swap");
    if (part1) |part| {
        sys.debug.print("find partition:{s}\r\n", .{part.name}) catch {};
        const ota_fw_info = @as(*const volatile Ota_FW_Info, @ptrFromInt(flash1.start + part.offset));

        // check ota_fw_info
        if (ota_fw_info.magic[0] != 'R' or ota_fw_info.magic[1] != 'B' or ota_fw_info.magic[2] != 'L') {
            sys.debug.print("magic not match, don't need swap\r\n", .{}) catch {};
            return;
        }
        const part2 = fal_partition.partition_find(@volatileCast(ota_fw_info.name[0..strlen(@volatileCast(ota_fw_info.name[0..]))]));
        if (part2) |part_target| {
            sys.debug.print("swap [{s}] to version:{s}\r\n", .{ ota_fw_info.name, ota_fw_info.version }) catch {};
            fal_partition.partition_erase(part_target, 0, ota_fw_info.raw_size);
            // copy data
            var buf: [1024]u8 = undefined;
            var offset: u32 = 0;
            while (offset < ota_fw_info.raw_size) : (offset += 1024) {
                const read_size = ota_fw_info.raw_size - offset;

                sys.debug.print("=", .{}) catch {};
                if (read_size > 1024) {
                    fal_partition.partition_read(part, offset + @sizeOf(Ota_FW_Info), &buf);
                    fal_partition.partition_write(part_target, offset, &buf);
                } else {
                    var tmp_bug: [1024]u8 = undefined;
                    fal_partition.partition_read(part, offset, &tmp_bug);
                    fal_partition.partition_write(part_target, offset, &tmp_bug);
                }
            }
            sys.debug.print("\r\nswap success, start clean swap parttion\r\n", .{}) catch {};
            // cleanup swap
            fal_partition.partition_erase(part, 0, ota_fw_info.pkg_size);
        } else {
            sys.debug.print("not find partition{s}\r\n", .{ota_fw_info.name}) catch {};
        }
    }
}
