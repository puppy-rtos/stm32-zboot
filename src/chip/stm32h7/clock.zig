const std = @import("std");
const cpu = @import("../cortex-m.zig");
const regs = @import("regs.zig").devices.stm32h7.peripherals;
const hal = @import("../../hal/hal.zig");

const RCC_CFGR_SW_HSI = 0;
const RCC_CFGR_SW_CSI = 1;
const RCC_CFGR_SW_HSE = 2;
const RCC_CFGR_SW_PLL1 = 3;

const RCC_PLLSOURCE_HSI = 0b00;
const RCC_PLLSOURCE_CSI = 0b01;
const RCC_PLLSOURCE_HSE = 0b10;
const RCC_PLLSOURCE_NONE = 0b11;

pub fn clock_init() void {

    // Enable power interface clock vos3 and latency4 max freq = 180Mhz
    regs.Flash.ACR.modify(.{ .LATENCY = 4 });

    // Enable HSI
    regs.RCC.CR.modify(.{ .HSION = 1 });
    // Wait for HSI ready
    while (regs.RCC.CR.read().HSIRDY != 1) {
        cpu.nop();
    }

    // Use HSI as system clock
    regs.RCC.CFGR.modify(.{ .SW = RCC_CFGR_SW_HSI });

    // Disable PLL
    regs.RCC.CR.modify(.{ .PLL1ON = 0 });
    // waiting PLLRDY is clear
    while (regs.RCC.CR.read().PLL1RDY != 0) {
        cpu.nop();
    }

    // HSI used as PLL clock source; freq:200Mhz
    regs.RCC.PLLCKSELR.modify(.{ .PLLSRC = RCC_PLLSOURCE_HSI, .DIVM1 = 4 });
    regs.RCC.PLLCFGR.modify(.{ .PLL1VCOSEL = 0, .PLL1RGE = 0b11, .PLL1FRACEN = 0, .DIVP1EN = 1, .DIVQ1EN = 1, .DIVR1EN = 1 });
    regs.RCC.PLL1DIVR.modify(.{ .DIVN1 = 24, .DIVP1 = 1 });

    // clear clock interrupt
    regs.RCC.CIER.raw = 0;

    // Enable PLL
    regs.RCC.CR.modify(.{ .PLL1ON = 1 });
    // Wait for PLL ready
    while (regs.RCC.CR.read().PLL1RDY != 1) {
        cpu.nop();
    }
    // Use PLL as system clock
    regs.RCC.CFGR.modify(.{ .SW = RCC_CFGR_SW_PLL1 });
    while (regs.RCC.CFGR.read().SWS != RCC_CFGR_SW_PLL1) {
        cpu.nop();
    }

    // init systick
    cpu.peripherals.SysTick.LOAD.raw = 0xFFFFFF;
    cpu.peripherals.SysTick.CTRL.modify(.{ .ENABLE = 1, .CLKSOURCE = 1 });
}

pub fn clock_deinit() void {
    // Reset clock
    cpu.peripherals.SysTick.CTRL.modify(.{ .ENABLE = 0 });
    regs.RCC.CFGR.raw = 0x00000000;
}

const CSI_VALUE: u32 = 4000000; // 4MHz
const HSI_VALUE: u32 = 64000000; // 64MHz
const HSE_VALUE: u32 = 8000000; // 8MHz

// get sysclk frequency It is calculated based on the predefined
//        constant and the selected clock source
pub fn get_sysfreq() u32 {
    var pllm: u32 = 0;
    var pllvco: u32 = 0;
    var pllp: u32 = 0;
    var sysclockfreq: u32 = 0;

    switch (regs.RCC.CFGR.read().SWS) {
        RCC_CFGR_SW_HSI => if (regs.RCC.CR.read().HSIDIVF != 0) {
            sysclockfreq = HSI_VALUE >> regs.RCC.CR.read().HSIDIV;
        } else {
            sysclockfreq = HSI_VALUE;
        }, // HSI
        RCC_CFGR_SW_HSE => sysclockfreq = HSE_VALUE, // HSE
        RCC_CFGR_SW_PLL1 => { // PLL
            //PLL_VCO = (HSE_VALUE or HSI_VALUCFGRE / PLLM) * PLLN
            //SYSCLK = PLL_VCO / PLLP
            const pllcource = regs.RCC.PLLCKSELR.read().PLLSRC;
            pllm = regs.RCC.PLLCKSELR.read().DIVM1;
            const pllfracen = regs.RCC.PLLCFGR.read().PLL1FRACEN;
            if (pllfracen != 0) {
                // fracn not supported
            }

            if (pllm != 0) {
                if (pllcource == RCC_PLLSOURCE_HSE) {
                    // HSE used as PLL clock source
                    pllvco = (HSE_VALUE / pllm) * (regs.RCC.PLL1DIVR.read().DIVN1 + 1);
                } else if (pllcource == RCC_PLLSOURCE_HSI) {
                    // HSI used as PLL clock source
                    if (regs.RCC.CR.read().HSIDIVF != 0) {
                        pllvco = (HSI_VALUE >> regs.RCC.CR.read().HSIDIV) / pllm * (regs.RCC.PLL1DIVR.read().DIVN1 + 1);
                    } else {
                        pllvco = HSI_VALUE / pllm * (regs.RCC.PLL1DIVR.read().DIVN1 + 1);
                    }
                } else if (pllcource == RCC_PLLSOURCE_CSI) {
                    // CSI not supported
                }
                pllp = (@as(u32, regs.RCC.PLL1DIVR.read().DIVP1) + 1);
                sysclockfreq = pllvco / pllp;
            } else {
                sysclockfreq = 0;
            }
        },
        else => sysclockfreq = CSI_VALUE, // CSI
    }
    return sysclockfreq;
}

pub const clock: hal.clock.ClockType = .{
    .init = &clock_init,
    .deinit = &clock_deinit,
    .get_sysfreq = &get_sysfreq,
};
