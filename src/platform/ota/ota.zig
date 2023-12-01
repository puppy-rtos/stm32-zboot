const sys = @import("../sys.zig");
const fal = @import("../fal/fal.zig");
const std = @import("std");

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

// ota check: check ota header
pub fn get_fw_info(part: *const fal.partition.Partition, tail: bool) ?Ota_FW_Info {
    var ota_fw_info: Ota_FW_Info = undefined;
    var slice_info = @as([*]u8, @ptrCast((&ota_fw_info)))[0..(@sizeOf(Ota_FW_Info))];

    if (tail) {
        fal.partition.read(part, part.len - @sizeOf(Ota_FW_Info), slice_info[0..]);
    } else {
        fal.partition.read(part, 0, slice_info[0..]);
    }

    // check ota_fw_info
    if (ota_fw_info.magic[0] != 'R' or ota_fw_info.magic[1] != 'B' or ota_fw_info.magic[2] != 'L') {
        // sys.debug.print("magic not match\r\n", .{}) catch {};
        return null;
    }
    // check hdr_crc by Crc32IsoHdlc
    const crc = std.hash.crc.Crc32IsoHdlc.hash(slice_info[0..(@sizeOf(Ota_FW_Info) - @sizeOf(u32))]);
    if (crc != ota_fw_info.hdr_crc) {
        sys.debug.print("hdr_crc not match\r\n", .{}) catch {};
        // print hdr_crc and crc
        sys.debug.print("hdr_crc:{x}, crc:{x}\r\n", .{ ota_fw_info.hdr_crc, crc }) catch {};
        return null;
    }

    return ota_fw_info;
}

// check partition crc
// pub fn checkCrc(part: *const fal.partition.Partition, tail: bool) bool {
//     var buf: [1024]u8 = undefined;
//     var offset: u32 = 0;
//     const ota_fw_info = get_fw_info(part, tail);
//     if (ota_fw_info == null) {
//         sys.debug.print("get_fw_info failed\r\n", .{}) catch {};
//         return false;
//     }
//     const len = ota_fw_info.?.pkg_size;
//     // check body_crc by Crc32IsoHdlc
//     var CRC = std.hash.crc.Crc32IsoHdlc.init();
//     if (tail == false) {
//         offset = @sizeOf(Ota_FW_Info);
//     }
//     while (offset < len) : (offset += 1024) {
//         const read_size = len - offset;
//         if (read_size > 1024) {
//             fal.partition.read(part, offset, &buf);
//             CRC.update(buf[0..]);
//         } else {
//             fal.partition.read(part, offset, buf[0..read_size]);
//             CRC.update(buf[0..read_size]);
//         }
//     }
//     const crc = CRC.final();
//     sys.debug.print("body_crc:{x}, crc:{x}", .{ ota_fw_info.?.body_crc, crc }) catch {};
//     return true;
// }

// ota swap: move swap to target partition
pub fn swap() void {
    const part = fal.partition.find("swap").?;
    const ret = get_fw_info(part, false);
    if (ret == null) {
        return;
    }
    const ota_fw_info = ret.?;

    // check app partition
    const part_target = fal.partition.find(@volatileCast(ota_fw_info.name[0..strlen(@volatileCast(ota_fw_info.name[0..]))])).?;
    const ret2 = get_fw_info(part_target, true);
    if (ret2 == null) {
        sys.debug.print("not find ota_fw_info in target partition\r\n", .{}) catch {};
        sys.debug.print("swap [{s}] {s} => {s}\r\n", .{ ota_fw_info.name, "unkown", ota_fw_info.version }) catch {};
    } else {
        const ota_fw_info_target = ret2.?;
        // if new version is same as old version, don't swap
        if (mem.eql(u8, ota_fw_info_target.version[0..], ota_fw_info.version[0..])) {
            sys.debug.print("version is same, don't need swap\r\n", .{}) catch {};
            return;
        }

        sys.debug.print("swap [{s}] {s} => {s}\r\n", .{ ota_fw_info.name, ota_fw_info_target.version, ota_fw_info.version }) catch {};
    }
    fal.partition.erase(part_target, 0, part_target.len);
    // copy data
    var buf: [1024]u8 = undefined;
    var offset: u32 = 0;
    while (offset < ota_fw_info.raw_size) : (offset += 1024) {
        const read_size = ota_fw_info.raw_size - offset;

        sys.debug.print("=", .{}) catch {};
        if (read_size > 1024) {
            fal.partition.read(part, offset + @sizeOf(Ota_FW_Info), &buf);
            fal.partition.write(part_target, offset, &buf);
        } else {
            var tmp_bug: [1024]u8 = undefined;
            fal.partition.read(part, offset + @sizeOf(Ota_FW_Info), &tmp_bug);
            fal.partition.write(part_target, offset, &tmp_bug);
        }
    }
    // write ota_info to target partition end
    const slice_info = @as([*]const u8, @ptrCast((&ota_fw_info)))[0..(@sizeOf(Ota_FW_Info))];
    fal.partition.write(part_target, part_target.len - @sizeOf(Ota_FW_Info), slice_info[0..]);

    sys.debug.print("\r\nswap success, start clean swap parttion\r\n", .{}) catch {};
}
