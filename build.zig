const std = @import("std");

const stm32f4 = std.Target.Query{
    .cpu_arch = .thumb,
    .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m3 },
    .os_tag = .freestanding,
    .abi = .eabi,
};

const examples = [_]Example{
    .{ .name = "stm32-app", .target = stm32f4, .root_file = "src/app_main.zig", .linker_script = "src/chip/link_app.lds" },
    .{ .name = "stm32-zboot", .target = stm32f4, .root_file = "src/main.zig", .linker_script = "src/chip/link.lds" },
};

pub fn build(b: *std.Build) void {
    const optimize = .ReleaseSmall;

    const zboot_tool = b.addExecutable(.{
        .name = "zboot",
        .optimize = .ReleaseSmall,
        .target = b.graph.host,
        .root_source_file = b.path("zboot.zig"),
    });

    const timestamp = std.time.timestamp();
    const options = b.addOptions();
    options.addOption(i64, "time_stamp", timestamp);

    for (examples) |example| {
        const elf = b.addExecutable(.{
            .name = b.fmt("{s}{s}", .{ example.name, ".elf" }),
            .root_source_file = b.path(example.root_file),
            .target = b.resolveTargetQuery(stm32f4),
            .optimize = optimize,
            .strip = false, // do not strip debug symbols
        });

        elf.setLinkerScript(b.path(example.linker_script));
        elf.addCSourceFile(.{ .file = b.path("src/chip/start.s"), .flags = &.{} });
        elf.root_module.addOptions("timestamp", options);

        // reduce the size of the binary
        elf.link_function_sections = true;
        elf.link_data_sections = true;
        elf.link_gc_sections = true;
        // elf.want_lto = true;

        // Copy the elf to the output directory.
        const copy_elf = b.addInstallArtifact(elf, .{});
        b.default_step.dependOn(&copy_elf.step);

        // Convert the hex from the elf
        const hex = b.addObjCopy(elf.getEmittedBin(), .{ .format = .hex });
        hex.step.dependOn(&elf.step);
        // Copy the hex to the output directory
        const copy_hex = b.addInstallBinFile(
            hex.getOutput(),
            b.fmt("{s}{s}", .{ example.name, ".hex" }),
        );
        b.default_step.dependOn(&copy_hex.step);

        // Convert the bin form the elf
        const bin = b.addObjCopy(elf.getEmittedBin(), .{ .format = .bin });
        bin.step.dependOn(&elf.step);

        // Copy the bin to the output directory
        const copy_bin = b.addInstallBinFile(
            bin.getOutput(),
            b.fmt("{s}{s}", .{ example.name, ".bin" }),
        );
        b.default_step.dependOn(&copy_bin.step);
        zboot_tool.step.dependOn(&copy_bin.step);
    }
    b.installArtifact(zboot_tool);
}

const Example = struct {
    target: std.Target.Query,
    name: []const u8,
    root_file: []const u8,
    linker_script: []const u8,
};
