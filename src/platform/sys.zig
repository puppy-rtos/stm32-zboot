const hal = @import("../hal/hal.zig");
pub const zconfig = @import("sys/config.zig");

pub var debug: hal.uart.UartDebug().Writer = undefined;

pub fn init_debug(name: []const u8) !void {
    debug = (try hal.uart.UartDebug().init(name)).writer();
}

/// Contains references to the microzig .data and .bss sections, also
/// contains the initial load address for .data if it is in flash.
pub const sections = struct {
    // it looks odd to just use a u8 here, but in C it's common to use a
    // char when linking these values from the linkerscript. What's
    // important is the addresses of these values.
    extern var microzig_data_start: u8;
    extern var microzig_data_end: u8;
    extern var microzig_bss_start: u8;
    extern var microzig_bss_end: u8;
    extern const microzig_data_load_start: u8;
};

pub fn get_rom_end() usize {
    const data_start: [*]u8 = @ptrCast(&sections.microzig_data_start);
    const data_end: [*]u8 = @ptrCast(&sections.microzig_data_end);
    const data_len = @intFromPtr(data_end) - @intFromPtr(data_start);
    const data_src: u32 = @intFromPtr(&sections.microzig_data_load_start);
    return data_src + data_len;
}
