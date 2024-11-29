const hal = @import("../../hal/hal.zig");
const sys = @import("../sys.zig");
const std = @import("std");

const Flash = @import("../fal/flash.zig");
const sfdp = @import("./sfud_sfdp.zig");

// sfud flash structure
pub const SfudFlash = struct {
    spi: hal.spi.SpiType,

    capacity: u32, // flash capacity
    write_size: u32, // flash write size
    erase_gran: u32, // erase granularity
    erase_gran_cmd: u8, // erase granularity command
    addr_in_4_byte: bool, // address in 4 byte mode
};

// SFUD CMD define
pub const SfudCmd = enum(u8) {
    WriteEnable = 0x06,
    WriteDisable = 0x04,
    ReadStatusRegister = 0x05,
    VolatileSrWriteEnable = 0x50,
    WriteStatusRegister = 0x01,
    PageProgram = 0x02,
    AaiWordProgram = 0xAD,
    EraseChip = 0xC7,
    ReadData = 0x03,
    DualOutputReadData = 0x3B,
    DualIoReadData = 0xBB,
    QuadIoReadData = 0xEB,
    QuadOutputReadData = 0x6B,
    ManufacturerDeviceId = 0x90,
    JedecId = 0x9F,
    ReadUniqueId = 0x4B,
    ReadSfdpRegister = 0x5A,
    EnableReset = 0x66,
    Reset = 0x99,
    Enter4bAddressMode = 0xB7,
    Exit4bAddressMode = 0xE9,
};

// status register bits
const SFUD_STATUS_REGISTER_BUSY = 0x01; // busing
const SFUD_STATUS_REGISTER_WEL = 0x02; // write enable latch
const SFUD_STATUS_REGISTER_SRP = 0x80; // status register protect

const SFUD_WRITE_MAX_PAGE_SIZE = 256;

// read status register
pub fn read_status_register(flash: *const SfudFlash) u8 {
    var cmd: [1]u8 = undefined;
    var status: [1]u8 = undefined;
    cmd[0] = @intFromEnum(SfudCmd.ReadStatusRegister);
    _ = flash.spi.wr(cmd[0..], status[0..]);
    return status[0];
}

// wait for last operation
pub fn wait_for_last_operation(flash: *const SfudFlash) bool {
    var status: u8 = 0;
    var retry_times: u32 = 1000000;
    while (true) {
        status = read_status_register(flash);
        if ((status & SFUD_STATUS_REGISTER_BUSY) == 0) {
            break;
        }
        retry_times -= 1;
        if (retry_times == 0) {
            sys.debug.print("Error: Flash wait busy has an error.\r\n", .{}) catch {};
            return false;
        }
    }
    return true;
}
// set flash write enable
pub fn set_flash_write_enable(flash: *const SfudFlash, enabled: bool) bool {
    var cmd: [1]u8 = undefined;
    var register_status: u8 = 0;

    if (enabled) {
        cmd[0] = @intFromEnum(SfudCmd.WriteEnable);
    } else {
        cmd[0] = @intFromEnum(SfudCmd.WriteDisable);
    }
    const result = flash.spi.wr(cmd[0..], null);
    if (result) {
        register_status = read_status_register(flash);
    }
    if (result) {
        if (enabled and (register_status & SFUD_STATUS_REGISTER_WEL) == 0) {
            sys.debug.print("Error: Can't enable write status.\r\n", .{}) catch {};
            return false;
        } else if (!enabled and (register_status & SFUD_STATUS_REGISTER_WEL) == 1) {
            sys.debug.print("Error: Can't disable write status.\r\n", .{}) catch {};
            return false;
        }
    }
    return result;
}

// set 4 byte address mode
pub fn set_4_byte_address_mode(flash: *SfudFlash, enabled: bool) bool {
    var cmd: [1]u8 = undefined;
    if (enabled) {
        cmd[0] = @intFromEnum(SfudCmd.Enter4bAddressMode);
    } else {
        cmd[0] = @intFromEnum(SfudCmd.Exit4bAddressMode);
    }
    // set the flash write enable
    var result = set_flash_write_enable(flash, true);
    if (result) {
        result = flash.spi.wr(cmd[0..], null);
    }

    if (result) {
        flash.addr_in_4_byte = enabled;
        if (enabled) {
            sys.debug.print("Enter 4-Byte addressing mode success.\r\n", .{}) catch {};
        } else {
            sys.debug.print("Exit 4-Byte addressing mode success.\r\n", .{}) catch {};
        }
    }
    return result;
}

pub fn flash_write(self: *const Flash.Flash_Dev, addr: u32, data: []const u8) Flash.FlashErr {
    _ = self;
    var cmd_data: [5 + SFUD_WRITE_MAX_PAGE_SIZE]u8 = undefined;
    var cmd_size: u8 = 0;
    var data_size: u32 = 0;
    var write_pos = addr;

    sys.debug.print("SFUD Flash write addr: 0x{x} size: 0x{x}\r\n", .{ addr, data.len }) catch {};

    if (addr + data.len > sfud_flash.capacity) {
        sys.debug.print("Error: Flash address is out of bound.\r\n", .{}) catch {};
        return Flash.FlashErr.OutOfBound;
    }
    var size: u32 = data.len;
    while (size > 0) {
        // print write_pos and size
        sys.debug.print("Write pos: 0x{x} size: 0x{x}\r\n", .{ write_pos, size }) catch {};
        // set the flash write enable
        var result = set_flash_write_enable(&sfud_flash, true);
        if (result != true) {
            sys.debug.print("Error: Flash write enable failed.\r\n", .{}) catch {};
            return Flash.FlashErr.ErrWrite;
        }
        cmd_size = make_flash_cmd_addr(&sfud_flash, SfudCmd.PageProgram, write_pos, &cmd_data);

        // make write align and calculate next write address
        if (write_pos % sfud_flash.write_size != 0) {
            if (size > sfud_flash.write_size - (write_pos % sfud_flash.write_size)) {
                data_size = sfud_flash.write_size - (write_pos % sfud_flash.write_size);
            } else {
                data_size = size;
            }
        } else {
            if (size > sfud_flash.write_size) {
                data_size = sfud_flash.write_size;
            } else {
                data_size = size;
            }
        }

        std.mem.copyForwards(u8, cmd_data[cmd_size .. cmd_size + data_size], data[(write_pos - addr) .. (write_pos - addr) + data_size]);
        result = sfud_flash.spi.wr(cmd_data[0 .. cmd_size + data_size], null);
        if (result != true) {
            sys.debug.print("Error: Flash write SPI communicate error.\r\n", .{}) catch {};
            return Flash.FlashErr.Transfer;
        }
        result = wait_for_last_operation(&sfud_flash);
        if (result != true) {
            sys.debug.print("Error: Flash wait busy has an error.\r\n", .{}) catch {};
            return Flash.FlashErr.Busy;
        }

        size -= data_size;
        write_pos += data_size;
    }
    // set the flash write disable
    _ = set_flash_write_enable(&sfud_flash, false);
    return Flash.FlashErr.Ok;
}

pub fn flash_read(self: *const Flash.Flash_Dev, addr: u32, data: []u8) Flash.FlashErr {
    _ = self;

    var result: bool = true;
    var cmd_data: [5]u8 = undefined;
    var cmd_size: u8 = 0;

    if (addr + data.len > sfud_flash.capacity) {
        sys.debug.print("Error: Flash address is out of bound.\r\n", .{}) catch {};
        return Flash.FlashErr.OutOfBound;
    }
    result = wait_for_last_operation(&sfud_flash);
    if (result != true) {
        sys.debug.print("Error: Flash wait busy has an error.\r\n", .{}) catch {};
        return Flash.FlashErr.Busy;
    }
    cmd_size = make_flash_cmd_addr(&sfud_flash, SfudCmd.ReadData, addr, &cmd_data);
    result = sfud_flash.spi.wr(cmd_data[0..cmd_size], data[0..]);
    if (result != true) {
        sys.debug.print("Error: Flash read SPI communicate error.\r\n", .{}) catch {};
        return Flash.FlashErr.Transfer;
    }
    return Flash.FlashErr.Ok;
}

// make cmd addr
fn make_flash_cmd_addr(flash: *const SfudFlash, cmd: SfudCmd, addr: u32, cmd_addr: []u8) u8 {
    var cmd_size: u8 = 0;
    cmd_addr[0] = @intFromEnum(cmd);
    if (flash.addr_in_4_byte) {
        cmd_addr[1] = @intCast(std.math.shr(u32, addr, 24));
        cmd_addr[2] = @intCast(std.math.shr(u32, addr, 16));
        cmd_addr[3] = @intCast(std.math.shr(u32, addr, 8));
        cmd_addr[4] = @intCast(std.math.shr(u32, addr, 0));
        cmd_size = 5;
    } else {
        cmd_addr[1] = @intCast(std.math.shr(u32, addr, 16));
        cmd_addr[2] = @intCast(std.math.shr(u32, addr, 8));
        cmd_addr[3] = @intCast(std.math.shr(u32, addr, 0));
        cmd_size = 4;
    }
    return cmd_size;
}

const ops: Flash.FlashOps = .{
    .init = null,
    .erase = null,
    .write = &flash_write,
    .read = &flash_read,
};

pub var sfud_flash: SfudFlash = .{
    .spi = undefined,
    .capacity = 0,
    .write_size = SFUD_WRITE_MAX_PAGE_SIZE,
    .erase_gran = 0,
    .erase_gran_cmd = 0,
    .addr_in_4_byte = false,
};
pub var spi_flash = Flash.Flash_Dev{
    .name = "spiflash",
    .start = 0x00000000,
    .len = 0,
    .blocks = .{
        .{ .size = 0, .count = 0 },
        .{ .size = 0, .count = 0 },
        .{ .size = 0, .count = 0 },
        .{ .size = 0, .count = 0 },
        .{ .size = 0, .count = 0 },
        .{ .size = 0, .count = 0 },
    },
    .write_size = SFUD_WRITE_MAX_PAGE_SIZE,
    .ops = &ops,
};

// probe flash by spi
pub fn probe(name: []const u8, spi: hal.spi.SpiType) ?*const Flash.Flash_Dev {
    _ = name;
    sfud_flash.spi = spi;
    if (sfdp.check_sfdp_header(&sfud_flash) == false) {
        return null;
    }
    if (sfdp.get_basic_para(&sfud_flash) == false) {
        return null;
    }

    // if the flash is large than 16MB (256Mb) then enter in 4-Byte addressing mode
    if (sfud_flash.capacity > (1 << 24)) {
        _ = set_4_byte_address_mode(&sfud_flash, true);
    } else {
        sfud_flash.addr_in_4_byte = false;
    }
    spi_flash.len = sfud_flash.capacity;
    spi_flash.blocks[0].size = sfud_flash.erase_gran;
    spi_flash.blocks[0].count = sfud_flash.capacity / sfud_flash.erase_gran;
    return &spi_flash;
}
