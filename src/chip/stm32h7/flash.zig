const regs = @import("regs.zig").devices.stm32h7.peripherals;
const cpu = @import("../cortex-m.zig");

const Flash = @import("../../platform/fal/flash.zig");
const sys = @import("../../platform/sys.zig");

const Debug = false;

const FLASH_KEYR_KEY1 = 0x45670123;
const FLASH_KEYR_KEY2 = 0xcdef89ab;

const FLASH_OPTKEYR_KEY1 = 0x08192a3b;
const FLASH_OPTKEYR_KEY2 = 0x4c5d6e7f;

const flash_size = @as(*u16, @ptrFromInt(0x1FF1E880));

// unlock stm32 flash
pub fn flash_unlock() void {
    // bank1
    regs.Flash.KEYR1.raw = FLASH_KEYR_KEY1;
    regs.Flash.KEYR1.raw = FLASH_KEYR_KEY2;

    // bank2
    regs.Flash.KEYR2.raw = FLASH_KEYR_KEY1;
    regs.Flash.KEYR2.raw = FLASH_KEYR_KEY2;
}

// lock stm32 flash
pub fn flash_lock() void {
    regs.Flash.CR1.modify(.{ .LOCK1 = 1 });
    regs.Flash.CR2.modify(.{ .LOCK2 = 1 });
}
// flash_clear_status_flags
pub fn flash_clear_status_flags() void {
    regs.Flash.CCR1.modify(.{ .CLR_PGSERR1 = 1, .CLR_WRPERR1 = 1, .CLR_EOP1 = 1, .CLR_OPERR1 = 1 });
    regs.Flash.CCR2.modify(.{ .CLR_PGSERR2 = 1, .CLR_WRPERR2 = 1, .CLR_EOP2 = 1, .CLR_OPERR2 = 1 });
}

pub fn flash_wait_for_last_operation() void {
    while (regs.Flash.SR1.read().BSY1 == 1 or regs.Flash.SR2.read().BSY2 == 1) {
        cpu.nop();
    }
}

pub const FLASH_CR_PROGRAM_X8 = 0;
pub const FLASH_CR_PROGRAM_X16 = 1;
pub const FLASH_CR_PROGRAM_X32 = 2;
pub const FLASH_CR_PROGRAM_X64 = 3;

pub fn flash_set_program_size(isbank1: bool, psize: u32) void {
    if (isbank1) {
        regs.Flash.CR1.modify(.{ .PSIZE1 = @as(u2, @intCast(psize)) });
    } else {
        regs.Flash.CR2.modify(.{ .PSIZE2 = @as(u2, @intCast(psize)) });
    }
}

// program an word(8 * 32 bit) to Flash
pub fn flash_program_32byte(address: u32, data: []const u8) void {
    flash_wait_for_last_operation();

    if (is_bank1(address)) {
        while (regs.Flash.SR1.read().WBNE1 == 1) {
            cpu.nop();
        }
        flash_set_program_size(true, FLASH_CR_PROGRAM_X8);
        regs.Flash.CR1.modify(.{ .PG1 = 1 });
    } else {
        while (regs.Flash.SR2.read().WBNE2 == 1) {
            cpu.nop();
        }
        flash_set_program_size(false, FLASH_CR_PROGRAM_X8);
        regs.Flash.CR2.modify(.{ .PG2 = 1 });
    }

    for (data, 0..) |d, i| {
        const addr: *volatile u8 = @ptrFromInt(address + i);
        addr.* = d;
    }

    flash_wait_for_last_operation();

    if (is_bank1(address)) {
        regs.Flash.CR1.modify(.{ .PG1 = 0 });
    } else {
        regs.Flash.CR2.modify(.{ .PG2 = 0 });
    }
}

var SECTER_PER_BANK: u32 = 1024 * 1024 / 2 / 2048; //
pub fn flash_init(self: *const Flash.Flash_Dev) Flash.FlashErr {
    SECTER_PER_BANK = flash_size.* * 1024 / self.blocks[0].size / 2;
    if (Debug) {
        sys.debug.print("chipflash size:0x{x}, SecterPerBank:0x{x}\r\n", .{ sys.zconfig.get_config().chipflash.size, SECTER_PER_BANK }) catch {};
    }
    return Flash.FlashErr.Ok;
}

// get bank1 or bank2 secter
pub fn is_bank1(addr: u32) bool {
    if ((addr - 0x8000000) < SECTER_PER_BANK * 0x20000) {
        return true;
    } else {
        return false;
    }
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
                if (secter_cur >= SECTER_PER_BANK) {
                    bank = 2;
                    pgn -= SECTER_PER_BANK;
                }
                if (Debug) {
                    sys.debug.print("chip erase bank:{d},secter_cur:{x}\r\n", .{ bank, pgn }) catch {};
                }
                if (bank == 1) {
                    regs.Flash.CR1.modify(.{ .SER1 = 1, .SNB1 = @as(u3, @intCast(pgn)) });
                    regs.Flash.CR1.modify(.{ .START1 = 1 });

                    flash_wait_for_last_operation();
                    regs.Flash.CR1.modify(.{ .SER1 = 0, .SNB1 = 0 });
                } else {
                    regs.Flash.CR2.modify(.{ .SER2 = 1, .SNB2 = @as(u3, @intCast(pgn)) });
                    regs.Flash.CR2.modify(.{ .START2 = 1 });

                    flash_wait_for_last_operation();
                    regs.Flash.CR2.modify(.{ .SER2 = 0, .SNB2 = 0 });
                }
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
    while (i < data.len) : (i += 32) {
        flash_program_32byte(addr + i, data[i .. i + 32]);

        // check data
        for (data[i .. i + 32], 0..) |d, j| {
            const addr8: *const volatile u8 = @ptrFromInt(addr + i + j);
            if (d != addr8.*) {
                sys.debug.print("write failed, data check error\r\n", .{}) catch {};
                ret = Flash.FlashErr.ErrWrite;
                break;
            }
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
        .{ .size = 0x20000, .count = 8 },
        .{ .size = 0, .count = 0 },
        .{ .size = 0, .count = 0 },
        .{ .size = 0, .count = 0 },
        .{ .size = 0, .count = 0 },
        .{ .size = 0, .count = 0 },
    },
    .write_size = 8,
    .ops = &ops,
};
