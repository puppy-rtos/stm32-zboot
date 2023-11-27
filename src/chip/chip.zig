const std = @import("std");

pub const pin = @import("stm32f4/pin.zig");
pub const clock = @import("stm32f4/clock.zig");
pub const flash = @import("stm32f4/flash.zig").chip_flash;

pub const linkscript = "stm32f4/link.ld";

const build_root = root();
const KiB = 1024;

pub const chips = struct {
    pub const stm32f4 = .{
        .preferred_format = .elf,
        .chip = .{
            .name = "stm32f4",
            .cpu = .cortex_m4,
            .memory_regions = &.{
                .{ .offset = 0x08000000, .length = 1024 * KiB, .kind = .flash },
                .{ .offset = 0x20000000, .length = 128 * KiB, .kind = .ram },
            },
            .register_definition = .{
                .zig = .{ .cwd_relative = build_root ++ "stm32f4/regs.zig" },
            },
        },
    };
};

fn root() []const u8 {
    return comptime (std.fs.path.dirname(@src().file) orelse ".") ++ "/";
}
