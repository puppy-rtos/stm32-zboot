pub const partition = @import("partition.zig");
pub const flash = @import("flash.zig");

const dconfig = @import("../../default_config.zig");
const sys = @import("../sys.zig");

// fal init
pub fn init() void {
    const onchip = flash.find("onchip").?;
    _ = onchip.init();
    partition.init(sys.get_rom_end());
    if (partition.partition_table.num == 0) {
        sys.debug.print("partition table not find, use default partition\r\n", .{}) catch {};
        // load default partition
        partition.init(@intFromPtr(&dconfig.default_partition));
    }
    partition.print();
}
