const microzig = @import("microzig");
const regs = @import("../chip.zig").regs;

const Flash = @import("../../platform/fal/flash.zig");
const sys = @import("../../platform/sys.zig");

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
    regs.FLASH.SR.modify(.{ .PGPERR = 1, .PGSERR = 1, .WRPERR = 1, .PGAERR = 1, .EOP = 1 });
}

pub const FLASH_CR_PROGRAM_X8 = 0;
pub const FLASH_CR_PROGRAM_X16 = 1;
pub const FLASH_CR_PROGRAM_X32 = 2;
pub const FLASH_CR_PROGRAM_X64 = 3;

pub fn flash_wait_for_last_operation() void {
    while (regs.FLASH.SR.read().BSY == 1) {
        microzig.cpu.nop();
    }
}

pub fn flash_set_program_size(psize: u32) void {
    regs.FLASH.CR.modify(.{ .PSIZE = @as(u2, @intCast(psize)) });
}

// Program an 8 bit Byte to FLASH
pub fn flash_program_byte(address: u32, data: u8) void {
    flash_wait_for_last_operation();
    flash_set_program_size(FLASH_CR_PROGRAM_X8);

    regs.FLASH.CR.modify(.{ .PG = 1 });

    const addr: *volatile u8 = @ptrFromInt(address);
    addr.* = data;

    flash_wait_for_last_operation();

    regs.FLASH.CR.modify(.{ .PG = 0 });
}

pub fn flash_init(self: *const Flash.Flash_Dev) Flash.FlashErr {
    _ = self;
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
                sys.debug.print("addr:{x}, cur_block:{x}\r\n", .{ addr, secter_cur }) catch {};
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
                if (Debug) {
                    sys.debug.print("chip erase secter_cur:{x}\r\n", .{secter_cur}) catch {};
                }
                // Erase the block
                flash_wait_for_last_operation();
                regs.FLASH.CR.modify(.{ .SER = 1, .SNB = @as(u4, @intCast(secter_cur)) });
                regs.FLASH.CR.modify(.{ .STRT = 1 });
                flash_wait_for_last_operation();
                regs.FLASH.CR.modify(.{ .SER = 0, .SNB = 0 });
            }
            if (addr_cur + b.size > addr + size) {
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
    flash_unlock();
    flash_clear_status_flags();

    for (data, 0..) |d, i| {
        flash_program_byte(addr + i, d);
    }

    flash_lock();
    return Flash.FlashErr.Ok;
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
        .{ .size = 0x4000, .count = 4 },
        .{ .size = 0x10000, .count = 1 },
        .{ .size = 0x20000, .count = 7 },
        .{ .size = 0x4000, .count = 4 },
        .{ .size = 0x10000, .count = 1 },
        .{ .size = 0x20000, .count = 7 },
    },
    .write_size = 8,
    .ops = &ops,
};
