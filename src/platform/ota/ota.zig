const sys = @import("../sys.zig");
const fal = @import("../fal/fal.zig");
const std = @import("std");

const mem = @import("std").mem;

const QBOOT_FASTLZ_BLOCK_HDR_SIZE = 4;

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
const table = [_]u32{ 0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f, 0xe963a535, 0x9e6495a3, 0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988, 0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91, 0x1db71064, 0x6ab020f2, 0xf3b97148, 0x84be41de, 0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7, 0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec, 0x14015c4f, 0x63066cd9, 0xfa0f3d63, 0x8d080df5, 0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172, 0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b, 0x35b5a8fa, 0x42b2986c, 0xdbbbc9d6, 0xacbcf940, 0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59, 0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423, 0xcfba9599, 0xb8bda50f, 0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924, 0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d, 0x76dc4190, 0x01db7106, 0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433, 0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d, 0x91646c97, 0xe6635c01, 0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e, 0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457, 0x65b0d9c6, 0x12b7e950, 0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65, 0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7, 0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0, 0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9, 0x5005713c, 0x270241aa, 0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f, 0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81, 0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a, 0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683, 0xe3630b12, 0x94643b84, 0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1, 0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb, 0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc, 0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5, 0xd6d6a3e8, 0xa1d1937e, 0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b, 0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55, 0x316e8eef, 0x4669be79, 0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236, 0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f, 0xc5ba3bbe, 0xb2bd0b28, 0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d, 0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f, 0x72076785, 0x05005713, 0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38, 0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21, 0x86d3d2d4, 0xf1d4e242, 0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777, 0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69, 0x616bffd3, 0x166ccf45, 0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2, 0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db, 0xaed16a4a, 0xd9d65adc, 0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9, 0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693, 0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94, 0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d };

// Calculate the CRC32 value of a memory buffer.
pub fn crc32(crc_input: u32, buf: []const u8) u32 {
    const init: u32 = 0xFFFFFFFF;
    var crc = crc_input ^ init;

    for (buf) |byte| {
        crc = table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }

    return crc ^ init;
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
    // check hdr_crc
    const crc = crc32(0, slice_info[0..(@sizeOf(Ota_FW_Info) - @sizeOf(u32))]);
    if (crc != ota_fw_info.hdr_crc) {
        sys.debug.print("hdr_crc not match\r\n", .{}) catch {};
        // print hdr_crc and crc
        sys.debug.print("hdr_crc:{x}, crc:{x}\r\n", .{ ota_fw_info.hdr_crc, crc }) catch {};
        return null;
    }

    return ota_fw_info;
}

// Calculate the hash value of a memory buffer.
pub fn calc_hash(hash_input: u32, buf: []const u8) u32 {
    var hash = hash_input;

    for (buf) |byte| {
        hash = (byte ^ hash) * 0x01000193;
    }

    return hash;
}

const ZBOOT_HASH_FNV_SEED: u32 = 0x811C9DC5;

// check partition fw hash
fn checkHash(name: []const u8) bool {
    var buf: [1024]u8 = undefined;
    var offset: u32 = 0;

    const part = fal.partition.find(name).?;

    const ota_fw_info = get_fw_info(part, true);
    if (ota_fw_info == null) {
        sys.debug.print("get_fw_info failed\r\n", .{}) catch {};
        return false;
    }
    const len = ota_fw_info.?.raw_size;
    // check body_crc
    var hash: u32 = ZBOOT_HASH_FNV_SEED;
    while (offset < len) : (offset += 1024) {
        const read_size = len - offset;
        if (read_size > 1024) {
            fal.partition.read(part, offset, buf[0..]);
            hash = calc_hash(hash, buf[0..]);
        } else {
            fal.partition.read(part, offset, buf[0..read_size]);
            hash = calc_hash(hash, buf[0..read_size]);
        }
    }
    if (hash != ota_fw_info.?.hash_code) {
        sys.debug.print("hash_code not match\r\n", .{}) catch {};
        // print hash_code and hash
        sys.debug.print("hash_code:{x}, hash:{x}\r\n", .{ ota_fw_info.?.hash_code, hash }) catch {};
        return false;
    }

    return true;
}

// check partition crc
fn checkCrc(name: []const u8) bool {
    var buf: [1024]u8 = undefined;
    var offset: u32 = 0;

    const part = fal.partition.find(name).?;

    const ota_fw_info = get_fw_info(part, false);
    if (ota_fw_info == null) {
        sys.debug.print("get_fw_info failed\r\n", .{}) catch {};
        return false;
    }
    var len = ota_fw_info.?.pkg_size;
    // check body_crc
    var crc: u32 = 0;
    offset = @sizeOf(Ota_FW_Info);
    len += offset;
    while (offset < len) : (offset += 1024) {
        const read_size = len - offset;
        if (read_size > 1024) {
            fal.partition.read(part, offset, buf[0..]);
            crc = crc32(crc, buf[0..]);
        } else {
            fal.partition.read(part, offset, buf[0..read_size]);
            crc = crc32(crc, buf[0..read_size]);
        }
    }
    if (crc != ota_fw_info.?.body_crc) {
        sys.debug.print("body_crc not match\r\n", .{}) catch {};
        // print body_crc and crc
        sys.debug.print("body_crc:{x}, crc:{x}\r\n", .{ ota_fw_info.?.body_crc, crc }) catch {};
        return false;
    }

    return true;
}

// check fw in partition, check crc in swap, and check hash in other partition
pub fn checkFW(name: []const u8) bool {
    if (mem.eql(u8, name[0..], "swap")) {
        return checkCrc(name);
    } else {
        return checkHash(name);
    }
}

// ota swap: move swap to target partition
pub fn swap() !void {
    const part = fal.partition.find("swap").?;
    const ret = get_fw_info(part, false);
    if (ret == null) {
        return;
    }
    const ota_fw_info = ret.?;

    // check swap partition crc
    if (checkCrc("swap") == false) {
        sys.debug.print("swap partition crc check failed\r\n", .{}) catch {};
        return;
    }

    // check app partition
    const part_target = fal.partition.find(@volatileCast(ota_fw_info.name[0..strlen(@volatileCast(ota_fw_info.name[0..]))])).?;
    const ret2 = get_fw_info(part_target, true);
    if (ret2 == null) {
        sys.debug.print("not find ota_fw_info in target partition\r\n", .{}) catch {};
        sys.debug.print("swap [{s}] {s} => {s}\r\n", .{ ota_fw_info.name, "unkown", ota_fw_info.version }) catch {};
    } else {
        const ota_fw_info_target = ret2.?;

        // check app
        // ota check app crc
        if (checkFW("app") == false) {
            sys.debug.print("app check failed\r\n", .{}) catch {};
        } else if (mem.eql(u8, ota_fw_info_target.version[0..], ota_fw_info.version[0..])) {
            // if new version is same as old version, don't swap
            sys.debug.print("version is same, don't need swap\r\n", .{}) catch {};
            return;
        }

        sys.debug.print("swap [{s}] {s} => {s}\r\n", .{ ota_fw_info.name, ota_fw_info_target.version, ota_fw_info.version }) catch {};
    }

    if (@intFromEnum(ota_fw_info.algo) & @intFromEnum(Ota_Algo.CMPRS_STAT_MASK) != 0) {
        const algo1 = @intFromEnum(ota_fw_info.algo) & @intFromEnum(Ota_Algo.CMPRS_STAT_MASK);
        switch (@as(Ota_Algo, @enumFromInt(algo1))) {
            Ota_Algo.GZIP => sys.debug.print("algo:GZIP\r\n", .{}) catch {},
            Ota_Algo.QUICKLZ => sys.debug.print("algo:QUICKLZ\r\n", .{}) catch {},
            Ota_Algo.FASTLZ => sys.debug.print("algo:FASTLZ\r\n", .{}) catch {},
            else => sys.debug.print("algo:unknown\r\n", .{}) catch {},
        }
    }
    // fastlz decompress
    if (@intFromEnum(ota_fw_info.algo) & @intFromEnum(Ota_Algo.CMPRS_STAT_MASK) == @intFromEnum(Ota_Algo.FASTLZ)) {
        sys.debug.print("fastlz decompress\r\n", .{}) catch {};

        // write decompress data to target partition
        fal.partition.erase(part_target, 0, part_target.len);
        var read_pos: usize = @sizeOf(Ota_FW_Info);
        var write_pos: usize = 0;
        while (read_pos < @sizeOf(Ota_FW_Info) + ota_fw_info.pkg_size) {
            var block_header: [QBOOT_FASTLZ_BLOCK_HDR_SIZE]u8 = undefined;
            var buffer: [1024 * 4]u8 = undefined;
            var o_buf: [1024 * 4]u8 = undefined;

            // read block size
            fal.partition.read(part, read_pos, block_header[0..]);
            read_pos += block_header.len;

            // decompress the buffer
            const blk_size = fastlz_get_block_size(block_header[0..]);
            if (blk_size <= 0) {
                sys.debug.print("blk_size error: {d}\r\n", .{blk_size}) catch {};
                return;
            }
            sys.debug.print("=", .{}) catch {};

            // read block data
            fal.partition.read(part, read_pos, buffer[0..blk_size]);
            read_pos += blk_size;

            const dec_size = fastlz1_decompress(o_buf[0..], buffer[0..blk_size]);
            // sys.debug.print("fastlz_decompress returned {d}\r\n", .{dec_size}) catch {};

            // write to file
            fal.partition.write(part_target, write_pos, o_buf[0..dec_size]);
            write_pos += dec_size;
        }
    } else {
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
    }
    // write ota_info to target partition end
    const slice_info = @as([*]const u8, @ptrCast((&ota_fw_info)))[0..(@sizeOf(Ota_FW_Info))];
    fal.partition.write(part_target, part_target.len - @sizeOf(Ota_FW_Info), slice_info[0..]);

    sys.debug.print("\r\nswap success, start clean swap parttion\r\n", .{}) catch {};
}

fn fastlz_get_block_size(comp_datas: []const u8) u32 {
    var block_size: u32 = 0;
    for (0..QBOOT_FASTLZ_BLOCK_HDR_SIZE) |i| {
        block_size <<= 8;
        block_size += comp_datas[i];
    }
    return (block_size);
}

fn FASTLZ_BOUND_CHECK(cond: bool) void {
    if (cond) return;
    sys.debug.print("fastlz:corrupt\r\n", .{}) catch {};
}

pub fn fastlz1_decompress(output: []u8, input: []const u8) usize {
    var ipIdx: u32 = 0;
    const ipLimitIdx = input.len;
    var opIdx: u32 = 0;
    const opLimitIdx = output.len;

    var ctrl: u8 = input[ipIdx] & 0b11111;
    ipIdx += 1;

    var loop = true;
    while (loop) {
        var len: u32 = ctrl >> 5;
        const ofs: u32 = std.math.shl(u32, (ctrl & 0b11111), 8);
        // dump len and ofs
        // std.debug.print("len:{d}, ofs:{d}\r\n", .{ len, ofs });

        if (ctrl >= 0b100000) {
            var refIdx: u32 = opIdx - ofs - 1;
            len -= 1;
            if (len == 7 - 1) {
                len += input[ipIdx];
                ipIdx += 1;
            }

            FASTLZ_BOUND_CHECK(ipIdx < ipLimitIdx);
            refIdx -= input[ipIdx];
            ipIdx += 1;

            if (ipIdx < ipLimitIdx) {
                ctrl = input[ipIdx];
                ipIdx += 1;
            } else {
                loop = false;
            }

            FASTLZ_BOUND_CHECK(opIdx + len + 3 <= opLimitIdx);
            FASTLZ_BOUND_CHECK(refIdx < opLimitIdx);
            if (refIdx == opIdx) {
                const b = output[refIdx];
                len += 3;
                @memset(output[opIdx .. opIdx + len], b);
                opIdx += len;
            } else {
                len += 3;
                std.mem.copyForwards(u8, output[opIdx .. opIdx + len], output[refIdx .. refIdx + len]);
                opIdx += len;
                refIdx += len;
            }
        } else {
            ctrl += 1;

            FASTLZ_BOUND_CHECK(opIdx + ctrl <= opLimitIdx);
            FASTLZ_BOUND_CHECK(ipIdx + ctrl <= ipLimitIdx);
            std.mem.copyForwards(u8, output[opIdx .. opIdx + ctrl], input[ipIdx .. ipIdx + ctrl]);
            opIdx += ctrl;
            ipIdx += ctrl;

            loop = ipIdx < ipLimitIdx;
            if (loop) {
                ctrl = input[ipIdx];
                ipIdx += 1;
            }
        }
    }
    return opIdx;
}
