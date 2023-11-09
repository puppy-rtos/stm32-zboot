const std = @import("std");
const regs = @import("../regs/stm32f4.zig").devices.stm32f4.peripherals;
const types = @import("../regs/stm32f4.zig").types;
const microzig = @import("microzig");

var sysfreq: u32 = 0;

pub fn clock_init() void {

    // Enable power interface clock
    regs.RCC.APB1ENR.modify(.{ .PWREN = 1 });

    // Enable HSI
    regs.RCC.CR.modify(.{ .HSION = 1 });
    // Wait for HSI ready
    while (regs.RCC.CR.read().HSIRDY != 1) {}

    // Use HSI as system clock
    regs.RCC.CFGR.modify(.{ .SW = 0b00 });

    // Disable PLL
    regs.RCC.CR.modify(.{ .PLLON = 0 });

    // HSI used as PLL clock source; PLLM = 8 PLLN = 80 PLLP = 2 PLLQ = 4
    regs.RCC.PLLCFGR.modify(.{ .PLLSRC = 0, .PLLM = 8, .PLLN = 80, .PLLP = 0b00, .PLLQ = 4 });

    // clear clock interrupt
    regs.RCC.CIR.raw = 0;

    // Prefetch enable; Instruction cache enable; Data cache enable; Set flash latency
    regs.FLASH.ACR.modify(.{ .PRFTEN = 1, .ICEN = 1, .DCEN = 1, .LATENCY = 0b010 });

    // Enable PLL
    regs.RCC.CR.modify(.{ .PLLON = 1 });
    // Wait for PLL ready
    while (regs.RCC.CR.read().PLLRDY != 1) {}
    // Use PLL as system clock
    regs.RCC.CFGR.modify(.{ .SW = 0b10 });
    while (regs.RCC.CFGR.read().SWS != 0b10) {}

    sysfreq = get_sysfreq();
    // init systick
    microzig.cpu.peripherals.SysTick.LOAD.raw = 0xFFFFFF;
    microzig.cpu.peripherals.SysTick.CTRL.modify(.{ .ENABLE = 1, .CLKSOURCE = 1 });
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

// delay_ms
pub fn delay_ms(ms: u32) void {
    for (0..ms) |i| {
        _ = i;
        delay_us(1000);
    }
}

// delay us
pub fn delay_us(us: u32) void {
    var ticks: u32 = 0;
    var start: u32 = 0;
    var current: u32 = 0;

    ticks = us * (sysfreq / 1000000);
    start = microzig.cpu.peripherals.SysTick.VAL.raw;
    while (true) {
        current = microzig.cpu.peripherals.SysTick.VAL.raw;
        if (start < current) {
            current = start + (0xFFFFFF - current);
        } else {
            current = start - current;
        }
        if (current > ticks) {
            break;
        }
    }
}
