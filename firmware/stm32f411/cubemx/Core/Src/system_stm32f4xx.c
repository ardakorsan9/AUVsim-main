#include "stm32f4xx.h"

uint32_t SystemCoreClock = 16000000U;

const uint8_t AHBPrescTable[16] = {0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 6, 7, 8, 9};
const uint8_t APBPrescTable[8]  = {0, 0, 0, 0, 1, 2, 3, 4};

void SystemInit(void)
{
#if (__FPU_PRESENT == 1) && (__FPU_USED == 1)
  SCB->CPACR |= ((3UL << 10*2) | (3UL << 11*2));
#endif
  RCC->CR |= (uint32_t)0x00000001U;
  RCC->CFGR = 0x00000000U;
  RCC->CR &= (uint32_t)0xFEF6FFFFU;
  RCC->PLLCFGR = 0x24003010U;
  RCC->CR &= (uint32_t)0xFFFBFFFFU;
  RCC->CIR = 0x00000000U;
  SCB->VTOR = FLASH_BASE | 0x00U;
}

void SystemCoreClockUpdate(void)
{
  uint32_t tmp;
  uint32_t pllvco;
  uint32_t pllp;
  uint32_t pllsource;
  uint32_t pllm;

  switch (RCC->CFGR & RCC_CFGR_SWS)
  {
    case RCC_CFGR_SWS_HSI:
      SystemCoreClock = HSI_VALUE;
      break;
    case RCC_CFGR_SWS_HSE:
      SystemCoreClock = HSE_VALUE;
      break;
    case RCC_CFGR_SWS_PLL:
      pllsource = (RCC->PLLCFGR & RCC_PLLCFGR_PLLSRC) >> 22;
      pllm = RCC->PLLCFGR & RCC_PLLCFGR_PLLM;
      if (pllsource != 0U)
      {
        pllvco = (HSE_VALUE / pllm) * ((RCC->PLLCFGR & RCC_PLLCFGR_PLLN) >> 6);
      }
      else
      {
        pllvco = (HSI_VALUE / pllm) * ((RCC->PLLCFGR & RCC_PLLCFGR_PLLN) >> 6);
      }
      pllp = (((RCC->PLLCFGR & RCC_PLLCFGR_PLLP) >> 16) + 1U) * 2U;
      SystemCoreClock = pllvco / pllp;
      break;
    default:
      SystemCoreClock = HSI_VALUE;
      break;
  }

  tmp = AHBPrescTable[((RCC->CFGR & RCC_CFGR_HPRE) >> 4)];
  SystemCoreClock >>= tmp;
}
