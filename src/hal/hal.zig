pub const pin = @import("pin.zig");
pub const uart = @import("uart.zig");
pub const spi = @import("spi.zig");

pub const clock = @import("clock.zig");
pub const flash = @import("flash.zig");
pub const cpu = @import("../chip/cortex-m.zig");

const mmio = @import("../chip/mmio.zig");
const mem = @import("std").mem;

pub const CoreType = enum(u12) {
    M0 = 0xc20, // Cortex-M0
    M3 = 0xc23, // Cortex-M3
    M4 = 0xc24, // Cortex-M4
    M7 = 0xc27, // Cortex-M7
    M33 = 0xd21, // Cortex-M33
    M23 = 0xd20, // Cortex-M23
    M55 = 0xd22, // Cortex-M55
};

pub const F4_PID = enum(u12) {
    STM32F40xxx_41xxx = 0x413,
    STM32F42xxx_43xxx = 0x419,
    STM32F401xB_C = 0x423,
    STM32F401xD_E = 0x433,
    STM32F410xx = 0x458,
    STM32F411xx = 0x431,
    STM32F412xx = 0x441,
    STM32F446xx = 0x421,
    STM32F469xx_479xx = 0x434,
    STM32F413xx_423xx = 0x463,
};

pub const L4_PID = enum(u12) {
    STM32L412xx_422xx = 0x464,
    STM32L43xxx_44xxx = 0x435,
    STM32L45xxx_46xxx = 0x462,
    STM32L47xxx_48xxx = 0x415,
    STM32L496xx_4A6xx = 0x461,
    STM32L4Rxx_4Sxx = 0x470,
    STM32L4P5xx_Q5xx = 0x471,
};

pub const H7_PID = enum(u12) {
    STM32H72xxx_73xxx = 0x483,
    STM32H74xxx_75xxx = 0x450,
    STM32H7A3xx_B3xx = 0x480,
};

pub const ChipSeriseType = enum {
    STM32F4,
    STM32L4,
    STM32H7,
};

const IDCODE = mmio.Mmio(packed struct(u32) {
    ///  DEV_ID
    DEV_ID: u12,
    reserved16: u4,
    ///  REV_ID
    REV_ID: u16,
});

pub var chip_series: ChipSeriseType = undefined;
pub var chip_flash_size: u32 = undefined;

pub fn init() void {
    const core_type: CoreType = @enumFromInt(cpu.peripherals.SCB.CPUID.read().PARTNO);
    switch (core_type) {
        CoreType.M0 => {},
        CoreType.M3 => {},
        CoreType.M4 => {
            const idcode = @as(*volatile IDCODE, @ptrFromInt(0xe0042000));
            const dev_id = idcode.read().DEV_ID;

            // if idcode match each F4 PID, then set chip_series to STM32F4
            if (dev_id == @intFromEnum(F4_PID.STM32F40xxx_41xxx) or
                dev_id == @intFromEnum(F4_PID.STM32F42xxx_43xxx) or
                dev_id == @intFromEnum(F4_PID.STM32F401xB_C) or
                dev_id == @intFromEnum(F4_PID.STM32F401xD_E) or
                dev_id == @intFromEnum(F4_PID.STM32F410xx) or
                dev_id == @intFromEnum(F4_PID.STM32F411xx) or
                dev_id == @intFromEnum(F4_PID.STM32F412xx) or
                dev_id == @intFromEnum(F4_PID.STM32F446xx) or
                dev_id == @intFromEnum(F4_PID.STM32F469xx_479xx) or
                dev_id == @intFromEnum(F4_PID.STM32F413xx_423xx))
            {
                chip_series = ChipSeriseType.STM32F4;
                chip_flash_size = @as(*u16, @ptrFromInt(0x1FFF7A22)).*;
            } else if (dev_id == @intFromEnum(L4_PID.STM32L412xx_422xx) or
                dev_id == @intFromEnum(L4_PID.STM32L43xxx_44xxx) or
                dev_id == @intFromEnum(L4_PID.STM32L45xxx_46xxx) or
                dev_id == @intFromEnum(L4_PID.STM32L47xxx_48xxx) or
                dev_id == @intFromEnum(L4_PID.STM32L496xx_4A6xx) or
                dev_id == @intFromEnum(L4_PID.STM32L4Rxx_4Sxx) or
                dev_id == @intFromEnum(L4_PID.STM32L4P5xx_Q5xx))
            {
                chip_series = ChipSeriseType.STM32L4;
                chip_flash_size = @as(*u16, @ptrFromInt(0x1FFF75E0)).*;
            }
        },
        CoreType.M7 => {
            const idcode = @as(*volatile IDCODE, @ptrFromInt(0x5C001000));
            const dev_id = idcode.read().DEV_ID;
            // if idcode match each H7 PID, then set chip_series to STM32H7
            if (dev_id == @intFromEnum(H7_PID.STM32H72xxx_73xxx) or
                dev_id == @intFromEnum(H7_PID.STM32H74xxx_75xxx) or
                dev_id == @intFromEnum(H7_PID.STM32H7A3xx_B3xx))
            {
                chip_series = ChipSeriseType.STM32H7;
                chip_flash_size = @as(*u16, @ptrFromInt(0x1FF1E880)).*;
            }
        },
        CoreType.M33 => {},
        CoreType.M23 => {},
        CoreType.M55 => {},
    }
    clock.init();
    flash.init();
    flash.chip_flash.len = chip_flash_size * 1024;
}
