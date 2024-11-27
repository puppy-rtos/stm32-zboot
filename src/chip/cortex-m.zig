const std = @import("std");
const mmio = @import("mmio.zig");

pub const regs = struct {
    // Interrupt Control and State Register
    pub const ICSR: *volatile mmio.Mmio(packed struct {
        VECTACTIVE: u9,
        reserved0: u2,
        RETTOBASE: u1,
        VECTPENDING: u9,
        reserved1: u1,
        ISRPENDING: u1,
        ISRPREEMPT: u1,
        reserved2: u1,
        PENDSTCLR: u1,
        PENDSTSET: u1,
        PENDSVCLR: u1,
        PENDSVSET: u1,
        reserved3: u2,
        NMIPENDSET: u1,
    }) = @ptrFromInt(0xE000ED04);
};

pub fn executing_isr() bool {
    return regs.ICSR.read().VECTACTIVE != 0;
}

pub fn enable_interrupts() void {
    asm volatile ("cpsie i");
}

pub fn disable_interrupts() void {
    asm volatile ("cpsid i");
}

pub fn enable_fault_irq() void {
    asm volatile ("cpsie f");
}
pub fn disable_fault_irq() void {
    asm volatile ("cpsid f");
}

pub fn nop() void {
    asm volatile ("nop");
}
pub fn wfi() void {
    asm volatile ("wfi");
}
pub fn wfe() void {
    asm volatile ("wfe");
}
pub fn sev() void {
    asm volatile ("sev");
}
pub fn isb() void {
    asm volatile ("isb");
}
pub fn dsb() void {
    asm volatile ("dsb");
}
pub fn dmb() void {
    asm volatile ("dmb");
}
pub fn clrex() void {
    asm volatile ("clrex");
}

fn is_valid_field(field_name: []const u8) bool {
    return !std.mem.startsWith(u8, field_name, "reserved") and
        !std.mem.eql(u8, field_name, "initial_stack_pointer") and
        !std.mem.eql(u8, field_name, "reset");
}

pub const peripherals = struct {
    ///  System Tick Timer
    pub const SysTick = @as(*volatile types.peripherals.SysTick, @ptrFromInt(0xe000e010));

    ///  System Control Space
    pub const NVIC = @compileError("TODO"); // @ptrFromInt(*volatile types.peripherals.NVIC, 0xe000e100);

    ///  System Control Block
    pub const SCB = @as(*volatile types.peripherals.SCB, @ptrFromInt(0xe000ed00));
};

pub const types = struct {
    pub const peripherals = struct {
        ///  System Tick Timer
        pub const SysTick = extern struct {
            ///  SysTick Control and Status Register
            CTRL: mmio.Mmio(packed struct(u32) {
                ENABLE: u1,
                TICKINT: u1,
                CLKSOURCE: u1,
                reserved16: u13,
                COUNTFLAG: u1,
                padding: u15,
            }),
            ///  SysTick Reload Value Register
            LOAD: mmio.Mmio(packed struct(u32) {
                RELOAD: u24,
                padding: u8,
            }),
            ///  SysTick Current Value Register
            VAL: mmio.Mmio(packed struct(u32) {
                CURRENT: u24,
                padding: u8,
            }),
            ///  SysTick Calibration Register
            CALIB: mmio.Mmio(packed struct(u32) {
                TENMS: u24,
                reserved30: u6,
                SKEW: u1,
                NOREF: u1,
            }),
        };

        ///  System Control Block
        pub const SCB = extern struct {
            CPUID: mmio.Mmio(packed struct(u32) {
                REVISION: u4,
                PARTNO: u12,
                ARCHITECTURE: u4,
                VARIANT: u4,
                IMPLEMENTER: u8,
            }),
            ///  Interrupt Control and State Register
            ICSR: mmio.Mmio(packed struct(u32) {
                VECTACTIVE: u9,
                reserved12: u3,
                VECTPENDING: u9,
                reserved22: u1,
                ISRPENDING: u1,
                ISRPREEMPT: u1,
                reserved25: u1,
                PENDSTCLR: u1,
                PENDSTSET: u1,
                PENDSVCLR: u1,
                PENDSVSET: u1,
                reserved31: u2,
                NMIPENDSET: u1,
            }),
            ///  Vector Table Offset Register
            VTOR: mmio.Mmio(packed struct(u32) {
                reserved8: u8,
                TBLOFF: u24,
            }),
            ///  Application Interrupt and Reset Control Register
            AIRCR: mmio.Mmio(packed struct(u32) {
                reserved1: u1,
                VECTCLRACTIVE: u1,
                SYSRESETREQ: u1,
                reserved15: u12,
                ENDIANESS: u1,
                VECTKEY: u16,
            }),
            ///  System Control Register
            SCR: mmio.Mmio(packed struct(u32) {
                reserved1: u1,
                SLEEPONEXIT: u1,
                SLEEPDEEP: u1,
                reserved4: u1,
                SEVONPEND: u1,
                padding: u27,
            }),
            ///  Configuration Control Register
            CCR: mmio.Mmio(packed struct(u32) {
                reserved3: u3,
                UNALIGN_TRP: u1,
                reserved9: u5,
                STKALIGN: u1,
                padding: u22,
            }),
            reserved28: [4]u8,
            ///  System Handlers Priority Registers. [0] is RESERVED
            SHP: u32,
            reserved36: [4]u8,
            ///  System Handler Control and State Register
            SHCSR: mmio.Mmio(packed struct(u32) {
                reserved15: u15,
                SVCALLPENDED: u1,
                padding: u16,
            }),
        };
    };
};
