const std = @import("std");
const microzig = @import("microzig");
const regs = microzig.chip.peripherals;

var sysfreq: u32 = 0;

const RCC_CFGR_SW_MSI = 0;
const RCC_CFGR_SW_HSI = 1;
const RCC_CFGR_SW_HSE = 2;
const RCC_CFGR_SW_PLL = 3;

const RCC_PLLSOURCE_MSI = 0b01;
const RCC_PLLSOURCE_HSI = 0b10;
const RCC_PLLSOURCE_HSE = 0b11;

pub fn clock_init() void {

    // Enable power interface clock
    regs.FLASH.ACR.modify(.{ .LATENCY = 4 });
    regs.PWR.CR1.modify(.{ .VOS = 1 });

    // Enable HSI
    regs.RCC.CR.modify(.{ .HSION = 1 });
    // Wait for HSI ready
    while (regs.RCC.CR.read().HSIRDY != 1) {
        microzig.cpu.nop();
    }

    // Use HSI as system clock
    regs.RCC.ICSCR.modify(.{ .HSITRIM = 64 }); // l496 need 64
    regs.RCC.CFGR.modify(.{ .SW = RCC_CFGR_SW_HSI });

    // Disable PLL
    regs.RCC.CR.modify(.{ .PLLON = 0 });
    // waiting PLLRDY is clear
    while (regs.RCC.CR.read().PLLRDY != 0) {
        microzig.cpu.nop();
    }

    // // HSI used as PLL clock source; PLLM = 8 PLLN = 80 PLLP = 2 PLLQ = 4
    regs.RCC.PLLCFGR.modify(.{ .PLLSRC = RCC_PLLSOURCE_HSI, .PLLM = 0, .PLLN = 10, .PLLP = 0, .PLLQ = 0, .PLLR = 0 });
    regs.RCC.PLLCFGR.modify(.{ .PLLREN = 1 });

    // clear clock interrupt
    regs.RCC.CIER.raw = 0;

    // Prefetch enable; Instruction cache enable; Data cache enable; Set flash latency
    regs.FLASH.ACR.modify(.{ .PRFTEN = 1, .ICEN = 1, .DCEN = 1, .LATENCY = 4 });

    // Enable PLL
    regs.RCC.CR.modify(.{ .PLLON = 1 });
    // Wait for PLL ready
    while (regs.RCC.CR.read().PLLRDY != 1) {
        microzig.cpu.nop();
    }
    // Use PLL as system clock
    regs.RCC.CFGR.modify(.{ .SW = RCC_CFGR_SW_PLL });
    while (regs.RCC.CFGR.read().SWS != RCC_CFGR_SW_PLL) {
        microzig.cpu.nop();
    }

    sysfreq = get_sysfreq();
    // init systick
    microzig.cpu.peripherals.SysTick.LOAD.raw = 0xFFFFFF;
    microzig.cpu.peripherals.SysTick.CTRL.modify(.{ .ENABLE = 1, .CLKSOURCE = 1 });
}

pub fn clock_deinit() void {
    // Reset clock
    microzig.cpu.peripherals.SysTick.CTRL.modify(.{ .ENABLE = 0 });
    regs.RCC.CFGR.raw = 0x00000000;
}

const MSI_VALUE = 4000000; // 4MHz
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
        RCC_CFGR_SW_MSI => sysclockfreq = MSI_VALUE, // MSI
        RCC_CFGR_SW_HSI => sysclockfreq = HSI_VALUE, // HSI
        RCC_CFGR_SW_HSE => sysclockfreq = HSE_VALUE, // HSE
        RCC_CFGR_SW_PLL => { // PLL
            //PLL_VCO = (HSE_VALUE or HSI_VALUCFGRE / PLLM) * PLLN
            //SYSCLK = PLL_VCO / PLLP
            const pllcfgr = regs.RCC.PLLCFGR.read();
            pllm = pllcfgr.PLLM + 1;
            if (pllcfgr.PLLSRC == RCC_PLLSOURCE_HSE) {
                // HSE used as PLL clock source
                pllvco = (HSE_VALUE / pllm) * pllcfgr.PLLN;
            } else if (pllcfgr.PLLSRC == RCC_PLLSOURCE_HSI) {
                // HSI used as PLL clock source
                pllvco = (HSI_VALUE / pllm) * pllcfgr.PLLN;
            } else if (pllcfgr.PLLSRC == RCC_PLLSOURCE_MSI) {
                // MSI used as PLL clock source
                pllvco = (MSI_VALUE / pllm) * pllcfgr.PLLN;
            }
            pllp = (@as(u32, pllcfgr.PLLP) + 1) * 2;
            sysclockfreq = pllvco / pllp;
        },
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
        microzig.cpu.nop();
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
