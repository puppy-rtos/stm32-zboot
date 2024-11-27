const std = @import("std");

const stm32f4 = std.zig.CrossTarget{
    .cpu_arch = .thumb,
    .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
    .os_tag = .freestanding,
    .abi = .eabihf,
};

const examples = [_]Example{
    .{ .name = "stm32-app", .target = stm32f4, .root_file = "src/app_main.zig", .linker_script = "src/chip/link_app.lds" },
    .{ .name = "stm32-zboot", .target = stm32f4, .root_file = "src/main.zig", .linker_script = "src/chip/link.lds" },
};

pub fn build(b: *std.Build) void {
    const optimize = .ReleaseSmall;

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
    }
    const zboot_tool = b.addExecutable(.{
        .name = "zboot",
        .optimize = .ReleaseSmall,
        .target = b.host,
        .root_source_file = b.path("src/zboot.zig"),
    });

    b.installArtifact(zboot_tool);
}

const Example = struct {
    target: std.zig.CrossTarget,
    name: []const u8,
    root_file: []const u8,
    linker_script: []const u8,
};
