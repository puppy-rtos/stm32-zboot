const std = @import("std");
const chips = @import("src/chip/chip.zig").chips;

const available_examples = [_]Example{
    .{ .name = "zboot-f4", .target = chips.stm32f4, .file = "src/main.zig", .linker_script = "src/chip/stm32f4/link.ld" },
    .{ .name = "zboot-f4-app", .target = chips.stm32f4, .file = "src/app_main.zig", .linker_script = "src/chip/stm32f4/link_app.ld" },
    .{ .name = "zboot-l4", .target = chips.stm32l4, .file = "src/main.zig", .linker_script = "src/chip/stm32f4/link.ld" },
    .{ .name = "zboot-l4-app", .target = chips.stm32l4, .file = "src/app_main.zig", .linker_script = "src/chip/stm32f4/link_app.ld" },
};

pub fn build(b: *std.Build) void {
    const microzig = @import("microzig").init(b, "microzig");
    const optimize = .ReleaseSmall; // The others are not really an option on AVR

    for (available_examples) |example| {
        // `addFirmware` basically works like addExecutable, but takes a
        // `microzig.Target` for target instead of a `std.zig.CrossTarget`.
        //
        // The target will convey all necessary information on the chip,
        // cpu and potentially the board as well.
        const firmware = microzig.addFirmware(b, .{
            .name = example.name,
            .target = example.target,
            .optimize = optimize,
            .source_file = .{ .path = example.file },
            .linker_script = .{ .source_file = .{ .path = example.linker_script } },
        });

        // `installFirmware()` is the MicroZig pendant to `Build.installArtifact()`
        // and allows installing the firmware as a typical firmware file.
        //
        // This will also install into `$prefix/firmware` instead of `$prefix/bin`.
        microzig.installFirmware(b, firmware, .{});

        // For debugging, we also always install the firmware as an ELF file
        microzig.installFirmware(b, firmware, .{ .format = .elf });

        microzig.installFirmware(b, firmware, .{ .format = .bin });
    }
    const zboot_tool = b.addExecutable(.{
        .name = "zboot",
        .optimize = .ReleaseSmall,
        .target = .{},
        .root_source_file = .{ .path = "src/zboot.zig" },
    });

    b.installArtifact(zboot_tool);
}

const Example = struct {
    target: @import("microzig").Target,
    name: []const u8,
    file: []const u8,
    linker_script: []const u8,
};
