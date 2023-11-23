pub const regs = @import("stm32f4/regs.zig").devices.stm32f4.peripherals;
pub const RegsTypes = @import("stm32f4/regs.zig").types.peripherals;

pub const pin = @import("stm32f4/pin.zig");
pub const clock = @import("stm32f4/clock.zig");
pub const flash = @import("stm32f4/flash.zig").chip_flash;

pub const linkscript = "stm32f4/link.ld";
