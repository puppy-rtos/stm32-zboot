const hal = @import("hal/hal.zig");
const sys = @import("platform/sys.zig");

pub fn main() !void {
    hal.clock.clock_init();
    sys.zconfig.probe_extconfig(sys.get_rom_end());
    const zboot_config = sys.zconfig.get_config();
    if (zboot_config.uart.enable) {
        sys.init_debug(zboot_config.uart.tx[0..]) catch {};
    }
    sys.debug.print("Hello Zboot App v1!\r\n", .{}) catch {};

    while (true) {}
}
