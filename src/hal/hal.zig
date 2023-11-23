pub const uart = @import("uart.zig");
pub const pin = @import("pin.zig");
pub const spi = @import("spi.zig");

pub const clock = @import("../chip/chip.zig").clock;
pub const flash = @import("../chip/chip.zig").flash;
