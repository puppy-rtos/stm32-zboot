const hal = @import("../../hal/hal.zig");
const sys = @import("../sys.zig");
const std = @import("std");

const SfudFlash = @import("sfud_flash.zig").SfudFlash;
const SfudCmd = @import("sfud_flash.zig").SfudCmd;

const sfdp_signature = 0x50444653;
const sfdp_basic_para_table_len = 9;

// SFDP Header structure
const SfdpHeader = packed struct {
    signature: u32, // SFDP signature
    minor_rev: u8,
    major_rev: u8,
    nph: u8, // Number of parameter headers
    sap: u8, // SFDP addressability parameter
};

// SFDP parameter header structure
const SfdpParaHeader = packed struct {
    id: u8, // Parameter ID LSB
    minor_rev: u8,
    major_rev: u8,
    len: u8, // Parameter table length(in double words)
    ptp: u24, // Parameter table 24bit pointer (byte address)
    id_msb: u8, // Parameter ID MSB
};

// check sfdp header
pub fn check_sfdp_header(flash: *const SfudFlash) bool {
    var header: SfdpHeader = undefined;
    var slice_header = @as([*]u8, @ptrCast((&header)))[0..(@sizeOf(SfdpHeader))];
    if (read_sfdp_data(flash, 0, slice_header[0..])) {
        // check SFDP header
        if (header.signature != sfdp_signature) {
            sys.debug.print("SFDP header error\r\n", .{}) catch {};
            return false;
        }
        sys.debug.print("Check SFDP header is OK. The reversion is V{d}.{d}, NPN is {d}.\r\n", .{ header.major_rev, header.minor_rev, header.nph }) catch {};
    }
    return true;
}

// JEDEC Basic Flash Parameter Table
const JBFPTable = packed struct { DWORD1: packed struct { erase_size: u2, write_gran: u1, used: u29 }, DWORD2: packed struct { flash_density: u31, abvoe_4g: u1 }, DWORD3: u32, DWORD4: u32, DWORD5: u32, DWORD6: u32, DWORD7: u32, DWORD8: packed struct {
    erase1_gran: u8,
    erase1_gran_cmd: u8,
    erase2_gran: u8,
    erase2_gran_cmd: u8,
} };

// probe basic flash parameter table
pub fn get_basic_para(flash: *SfudFlash) bool {
    var header: SfdpParaHeader = undefined;
    var slice_header = @as([*]u8, @ptrCast((&header)))[0..(@sizeOf(SfdpParaHeader))];
    if (read_sfdp_data(flash, 8, slice_header[0..])) {
        // check SFDP para header
        if (header.major_rev > 1) {
            sys.debug.print("This reversion(V{d}.{d}) JEDEC flash parameter header is not supported.", .{ header.major_rev, header.minor_rev }) catch {};
            return false;
        }
    }
    var table: JBFPTable = undefined;
    var slice_table = @as([*]u8, @ptrCast((&table)))[0..(@sizeOf(JBFPTable))];
    _ = read_sfdp_data(flash, @intCast(header.ptp), slice_table[0..]);
    // dump flash density
    if (table.DWORD2.abvoe_4g == 0) {
        flash.capacity = 1 + (table.DWORD2.flash_density >> 3);
    } else {
        flash.capacity = std.math.shl(u32, 1, table.DWORD2.flash_density - 3);
    }
    sys.debug.print("Flash density is {d} Mbit.\r\n", .{flash.capacity / 1024 / 1024 * 8}) catch {};

    // dump erase granularity
    if (table.DWORD8.erase1_gran != 0x0C) {
        sys.debug.print("Erase granularity 4K is not supported.\r\n", .{}) catch {};
    }
    flash.erase_gran = std.math.shl(u32, 1, table.DWORD8.erase1_gran);
    flash.erase_gran_cmd = table.DWORD8.erase1_gran_cmd;
    return true;
}

// read_sfdp_data
fn read_sfdp_data(flash: *const SfudFlash, offset: u32, read_buf: []u8) bool {
    const cmd = [_]u8{ @intFromEnum(SfudCmd.ReadSfdpRegister), @intCast(std.math.shr(u32, offset, 16)), @intCast(std.math.shr(u32, offset, 8)), @intCast(std.math.shr(u32, offset, 0)), 0xFF };
    return flash.spi.wr(cmd[0..], read_buf);
}

// dump sfdp header
fn dump_sfdp_header(header: SfdpHeader) void {
    sys.debug.print("signature: 0x{x}\r\n", .{header.signature}) catch {};
    sys.debug.print("minor_rev: 0x{x}\r\n", .{header.minor_rev}) catch {};
    sys.debug.print("major_rev: 0x{x}\r\n", .{header.major_rev}) catch {};
    sys.debug.print("nph: 0x{x}\r\n", .{header.nph}) catch {};
    sys.debug.print("sap: 0x{x}\r\n", .{header.sap}) catch {};
}

// dump sfdp para header
fn dump_sfdp_para_header(header: SfdpParaHeader) void {
    sys.debug.print("id: 0x{x}\r\n", .{header.id}) catch {};
    sys.debug.print("minor_rev: 0x{x}\r\n", .{header.minor_rev}) catch {};
    sys.debug.print("major_rev: 0x{x}\r\n", .{header.major_rev}) catch {};
    sys.debug.print("len: 0x{x}\r\n", .{header.len}) catch {};
    sys.debug.print("ptp: 0x{x}\r\n", .{header.ptp}) catch {};
    sys.debug.print("id_msb: 0x{x}\r\n", .{header.id_msb}) catch {};
}
