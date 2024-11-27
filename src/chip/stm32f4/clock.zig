const std = @import("std");
const cpu = @import("../cortex-m.zig");
const regs = @import("regs.zig").devices.stm32f4.peripherals;

pub fn clock_init() void {

    // Enable power interface clock
    regs.RCC.APB1ENR.modify(.{ .PWREN = 1 });

    // Enable HSI
    regs.RCC.CR.modify(.{ .HSION = 1 });
    // Wait for HSI ready
    while (regs.RCC.CR.read().HSIRDY != 1) {
        asm volatile ("nop");
    }

    // Use HSI as system clock
    regs.RCC.CFGR.modify(.{ .SW = 0b00 });

    // Disable PLL
    regs.RCC.CR.modify(.{ .PLLON = 0 });

    // HSI used as PLL clock source; PLLM = 8 PLLN = 80 PLLP = 2 PLLQ = 4
    regs.RCC.PLLCFGR.modify(.{ .PLLSRC = 0, .PLLM = 8, .PLLN = 80, .PLLP = 0b00, .PLLQ = 4 });

    // clear clock interrupt
    regs.RCC.CIR.write_raw(0);

    // Prefetch enable; Instruction cache enable; Data cache enable; Set flash latency
    regs.FLASH.ACR.modify(.{ .PRFTEN = 1, .ICEN = 1, .DCEN = 1, .LATENCY = 0b010 });

    // Enable PLL
    regs.RCC.CR.modify(.{ .PLLON = 1 });
    // Wait for PLL ready
    while (regs.RCC.CR.read().PLLRDY != 1) {
        asm volatile ("nop");
    }
    // Use PLL as system clock
    regs.RCC.CFGR.modify(.{ .SW = 0b10 });
    while (regs.RCC.CFGR.read().SWS != 0b10) {
        asm volatile ("nop");
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

const HSI_VALUE = 16000000; // 16MHz
const HSE_VALUE = 8000000; // 8MHz

// get sysclk frequency It is calculated based on the predefined
//        constant and the selected clock source
pub fn get_sysfreq() u32 {
    var pllm: u32 = 0;
    var pllvco: u32 = 0;
    var pllp: u32 = 0;
    var sysclockfreq: u32 = 0;

    switch (regs.RCC.CFGR.read().SWS) {
        0b00 => sysclockfreq = HSI_VALUE, // HSI
        0b01 => sysclockfreq = HSE_VALUE, // HSE
        0b10 => { // PLL
            //PLL_VCO = (HSE_VALUE or HSI_VALUE / PLLM) * PLLN
            //SYSCLK = PLL_VCO / PLLP
            const pllcfgr = regs.RCC.PLLCFGR.read();
            pllm = pllcfgr.PLLM;
            if (pllcfgr.PLLSRC == 1) {
                // HSE used as PLL clock source
                pllvco = (HSE_VALUE / pllm) * pllcfgr.PLLN;
            } else {
                // HSI used as PLL clock source
                pllvco = (HSI_VALUE / pllm) * pllcfgr.PLLN;
            }
            pllp = (pllcfgr.PLLP + 1) * 2;
            sysclockfreq = pllvco / pllp;
        },
        0b11 => return 0,
    }
    return sysclockfreq;
}

pub const clock = .{
    .init = &clock_init,
    .deinit = &clock_deinit,
    .get_sysfreq = &get_sysfreq,
};
