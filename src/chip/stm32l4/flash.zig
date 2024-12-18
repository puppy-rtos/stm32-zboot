const regs = @import("regs.zig").devices.stm32l4.peripherals;
const cpu = @import("../cortex-m.zig");

const Flash = @import("../../platform/fal/flash.zig");
const sys = @import("../../platform/sys.zig");
const hal = @import("../../hal/hal.zig");

const Debug = false;

const FLASH_KEYR_KEY1 = 0x45670123;
const FLASH_KEYR_KEY2 = 0xcdef89ab;

const FLASH_OPTKEYR_KEY1 = 0x08192a3b;
const FLASH_OPTKEYR_KEY2 = 0x4c5d6e7f;

// unlock stm32 flash
pub fn flash_unlock() void {
    regs.FLASH.KEYR.raw = FLASH_KEYR_KEY1;
    regs.FLASH.KEYR.raw = FLASH_KEYR_KEY2;
}

// lock stm32 flash
pub fn flash_lock() void {
    regs.FLASH.CR.modify(.{ .LOCK = 1 });
}
// flash_clear_status_flags
pub fn flash_clear_status_flags() void {
    regs.FLASH.SR.modify(.{ .PGSERR = 1, .SIZERR = 1, .PGAERR = 1, .WRPERR = 1, .PROGERR = 1, .EOP = 1 });
}

pub fn flash_wait_for_last_operation() void {
    while (regs.FLASH.SR.read().BSY == 1) {
        cpu.nop();
    }
}

// program an word(64 bit) to Flash
pub fn flash_program_64(address: u32, data: u64) void {
    flash_wait_for_last_operation();

    regs.FLASH.CR.modify(.{ .PG = 1 });

    const addr: *volatile u64 = @ptrFromInt(address);
    addr.* = data;

    flash_wait_for_last_operation();

    regs.FLASH.CR.modify(.{ .PG = 0 });
}

var SECTER_PER_BANK: u32 = 1024 * 1024 / 2 / 2048; // l496 1M flash, l475 512K flash
pub fn flash_init(self: *const Flash.Flash_Dev) Flash.FlashErr {
    SECTER_PER_BANK = hal.chip_flash_size * 1024 / self.blocks[0].size / 2;
    if (Debug) {
        sys.debug.print("chipflash size:0x{x}, SecterPerBank:0x{x}\r\n", .{ sys.zconfig.get_config().chipflash.size, SECTER_PER_BANK }) catch {};
    }
    return Flash.FlashErr.Ok;
}

pub fn flash_earse(self: *const Flash.Flash_Dev, addr: u32, size: u32) Flash.FlashErr {
    flash_unlock();
    flash_clear_status_flags();
    // Iterate the flash block, calculate which block addr and size belongs to, and then erase it

    var addr_cur = self.start;
    var secter_cur: u32 = 0;
    var is_find: bool = false;
    for (self.blocks) |b| {
        const is_ok = for (0..b.count) |i| {
            _ = i;

            if (Debug) {
                sys.debug.print("addr_cur:0x{x}, cur_block:0x{x}\r\n", .{ addr_cur, secter_cur }) catch {};
            }
            if (is_find == false) {
                if (addr >= addr_cur and addr < addr_cur + b.size) {
                    if (Debug) {
                        sys.debug.print("finded first block:{x}\r\n", .{secter_cur}) catch {};
                    }
                    is_find = true;
                } else {
                    addr_cur += b.size;
                    secter_cur += 1;
                    continue;
                }
            }

            if (addr < addr_cur + b.size) {
                var bank: u8 = 1;
                var pgn = secter_cur;

                // Erase the block
                flash_wait_for_last_operation();
                if (regs.FLASH.OPTR.read().DUALBANK == 0) {
                    regs.FLASH.CR.modify(.{ .BKER = 0 });
                } else {
                    if (secter_cur < SECTER_PER_BANK) {
                        regs.FLASH.CR.modify(.{ .BKER = 0 });
                    } else {
                        regs.FLASH.CR.modify(.{ .BKER = 1 });
                        bank = 2;
                        pgn -= SECTER_PER_BANK;
                    }
                }
                if (Debug) {
                    sys.debug.print("chip erase bank:{d},secter_cur:{x}\r\n", .{ bank, pgn }) catch {};
                }
                regs.FLASH.CR.modify(.{ .PER = 1, .PNB = @as(u8, @intCast(pgn)) });
                regs.FLASH.CR.modify(.{ .START = 1 });
                flash_wait_for_last_operation();
                regs.FLASH.CR.modify(.{ .PER = 0, .PNB = 0 });
                if (Debug) {
                    for (addr_cur..addr_cur + b.size) |check_d| {
                        const d = @as(*u8, @ptrFromInt(check_d)).*;
                        if (d != 0xFF) {
                            sys.debug.print("erase failed, data check error\r\n", .{}) catch {};
                            break;
                        }
                    }
                }
            }
            if (addr_cur + b.size >= addr + size) {
                break true;
            }

            addr_cur += b.size;
            secter_cur += 1;
        } else false;
        if (is_ok) {
            break;
        }
    }

    flash_lock();
    return Flash.FlashErr.Ok;
}
pub fn flash_write(self: *const Flash.Flash_Dev, addr: u32, data: []const u8) Flash.FlashErr {
    _ = self;
    var ret = Flash.FlashErr.Ok;
    flash_unlock();
    flash_clear_status_flags();

    var i: u32 = 0;
    while (i < data.len) : (i += 8) {
        const data64 = @as(*const volatile u64, @ptrCast(@alignCast(&data[i]))).*;
        flash_program_64(addr + i, data64);

        const addr64: *const volatile u64 = @ptrFromInt(addr + i);
        if (addr64.* != data64) {
            sys.debug.print("write failed, data check error!\r\n", .{}) catch {};
            ret = Flash.FlashErr.ErrWrite;
            break;
        }
    }

    flash_lock();
    return ret;
}
pub fn flash_read(self: *const Flash.Flash_Dev, addr: u32, data: []u8) Flash.FlashErr {
    _ = self;

    // read data from onchip flash
    for (data, 0..) |*d, i| {
        d.* = @as(*u8, @ptrFromInt(addr + i)).*;
    }
    return Flash.FlashErr.Ok;
}

const ops: Flash.FlashOps = .{
    .init = &flash_init,
    .erase = &flash_earse,
    .write = &flash_write,
    .read = &flash_read,
};

pub const chip_flash: Flash.Flash_Dev = .{
    .name = "onchip",
    .start = 0x08000000,
    .len = 0x100000,
    .blocks = .{
        .{ .size = 0x800, .count = 512 },
        .{ .size = 0, .count = 0 },
        .{ .size = 0, .count = 0 },
        .{ .size = 0, .count = 0 },
        .{ .size = 0, .count = 0 },
        .{ .size = 0, .count = 0 },
    },
    .write_size = 8,
    .ops = &ops,
};
