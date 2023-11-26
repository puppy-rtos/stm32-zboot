const hal = @import("../hal/hal.zig");
pub const zconfig = @import("sys/config.zig");

pub var debug: hal.uart.UartDebug().Writer = undefined;

pub fn init_debug(name: []const u8) !void {
    debug = (try hal.uart.UartDebug().init(name)).writer();
    debug.writeAll("\r\n===============debug uart inited===============\r\n") catch {};
}
