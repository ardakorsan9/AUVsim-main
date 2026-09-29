#include "stm32f4xx_hal.h"

#define HSE_TIMEOUT_VALUE 100U
#define PLL_TIMEOUT_VALUE 100U

static uint32_t RCC_GetSysClockFreq_Private(void);

HAL_StatusTypeDef HAL_RCC_OscConfig(RCC_OscInitTypeDef *RCC_OscInitStruct)
{
  uint32_t tickstart;

  if (RCC_OscInitStruct == NULL)
  {
    return HAL_ERROR;
  }

  if (((RCC_OscInitStruct->OscillatorType) & RCC_OSCILLATORTYPE_HSE) == RCC_OSCILLATORTYPE_HSE)
  {
    if (RCC_OscInitStruct->HSEState == RCC_HSE_ON)
    {
      SET_BIT(RCC->CR, RCC_CR_HSEON);
    }
    else if (RCC_OscInitStruct->HSEState == RCC_HSE_BYPASS)
    {
      SET_BIT(RCC->CR, RCC_CR_HSEBYP);
      SET_BIT(RCC->CR, RCC_CR_HSEON);
    }
    else
    {
      CLEAR_BIT(RCC->CR, RCC_CR_HSEON);
      CLEAR_BIT(RCC->CR, RCC_CR_HSEBYP);
    }

    if (RCC_OscInitStruct->HSEState != RCC_HSE_OFF)
    {
      tickstart = HAL_GetTick();
      while (READ_BIT(RCC->CR, RCC_CR_HSERDY) == 0U)
      {
        if ((HAL_GetTick() - tickstart) > HSE_TIMEOUT_VALUE)
        {
          return HAL_TIMEOUT;
        }
      }
    }
  }

  if (RCC_OscInitStruct->PLL.PLLState == RCC_PLL_ON)
  {
    CLEAR_BIT(RCC->CR, RCC_CR_PLLON);
    tickstart = HAL_GetTick();
    while (READ_BIT(RCC->CR, RCC_CR_PLLRDY) != 0U)
    {
      if ((HAL_GetTick() - tickstart) > PLL_TIMEOUT_VALUE)
      {
        return HAL_TIMEOUT;
      }
    }

    WRITE_REG(RCC->PLLCFGR,
              (RCC_OscInitStruct->PLL.PLLSource) |
              (RCC_OscInitStruct->PLL.PLLM) |
              ((RCC_OscInitStruct->PLL.PLLN) << 6U) |
              ((((RCC_OscInitStruct->PLL.PLLP) >> 1U) - 1U) << 16U) |
              ((RCC_OscInitStruct->PLL.PLLQ) << 24U));

    SET_BIT(RCC->CR, RCC_CR_PLLON);
    tickstart = HAL_GetTick();
    while (READ_BIT(RCC->CR, RCC_CR_PLLRDY) == 0U)
    {
      if ((HAL_GetTick() - tickstart) > PLL_TIMEOUT_VALUE)
      {
        return HAL_TIMEOUT;
      }
    }
  }

  return HAL_OK;
}

HAL_StatusTypeDef HAL_RCC_ClockConfig(RCC_ClkInitTypeDef *RCC_ClkInitStruct, uint32_t FLatency)
{
  uint32_t tickstart;

  if (RCC_ClkInitStruct == NULL)
  {
    return HAL_ERROR;
  }

  MODIFY_REG(FLASH->ACR, FLASH_ACR_LATENCY, FLatency);
  if ((FLASH->ACR & FLASH_ACR_LATENCY) != FLatency)
  {
    return HAL_ERROR;
  }

  if (((RCC_ClkInitStruct->ClockType) & RCC_CLOCKTYPE_HCLK) == RCC_CLOCKTYPE_HCLK)
  {
    MODIFY_REG(RCC->CFGR, RCC_CFGR_HPRE, RCC_ClkInitStruct->AHBCLKDivider);
  }

  if (((RCC_ClkInitStruct->ClockType) & RCC_CLOCKTYPE_SYSCLK) == RCC_CLOCKTYPE_SYSCLK)
  {
    MODIFY_REG(RCC->CFGR, RCC_CFGR_SW, RCC_ClkInitStruct->SYSCLKSource);
    tickstart = HAL_GetTick();
    while ((RCC->CFGR & RCC_CFGR_SWS) != (RCC_ClkInitStruct->SYSCLKSource << 2))
    {
      if ((HAL_GetTick() - tickstart) > 5000U)
      {
        return HAL_TIMEOUT;
      }
    }
  }

  if (((RCC_ClkInitStruct->ClockType) & RCC_CLOCKTYPE_PCLK1) == RCC_CLOCKTYPE_PCLK1)
  {
    MODIFY_REG(RCC->CFGR, RCC_CFGR_PPRE1, RCC_ClkInitStruct->APB1CLKDivider);
  }

  if (((RCC_ClkInitStruct->ClockType) & RCC_CLOCKTYPE_PCLK2) == RCC_CLOCKTYPE_PCLK2)
  {
    /* PPRE2 is bits 15:13; reuse same divider encoding shifted */
    MODIFY_REG(RCC->CFGR, RCC_CFGR_PPRE2, (RCC_ClkInitStruct->APB2CLKDivider) << 3);
  }

  SystemCoreClock = HAL_RCC_GetSysClockFreq() >> AHBPrescTable[(RCC->CFGR & RCC_CFGR_HPRE) >> 4];

  /* Reprogram SysTick after clock change */
  if (HAL_InitTick(TICK_INT_PRIORITY) != HAL_OK)
  {
    return HAL_ERROR;
  }

  return HAL_OK;
}

static uint32_t RCC_GetSysClockFreq_Private(void)
{
  uint32_t pllm;
  uint32_t plln;
  uint32_t pllp;
  uint32_t pllvco;
  uint32_t sysclockfreq;

  switch (RCC->CFGR & RCC_CFGR_SWS)
  {
    case RCC_CFGR_SWS_HSI:
      sysclockfreq = HSI_VALUE;
      break;
    case RCC_CFGR_SWS_HSE:
      sysclockfreq = HSE_VALUE;
      break;
    case RCC_CFGR_SWS_PLL:
    default:
      pllm = RCC->PLLCFGR & RCC_PLLCFGR_PLLM;
      plln = (RCC->PLLCFGR & RCC_PLLCFGR_PLLN) >> 6;
      pllp = ((((RCC->PLLCFGR & RCC_PLLCFGR_PLLP) >> 16) + 1U) * 2U);
      if ((RCC->PLLCFGR & RCC_PLLCFGR_PLLSRC) != 0U)
      {
        pllvco = (HSE_VALUE / pllm) * plln;
      }
      else
      {
        pllvco = (HSI_VALUE / pllm) * plln;
      }
      sysclockfreq = pllvco / pllp;
      break;
  }
  return sysclockfreq;
}

uint32_t HAL_RCC_GetSysClockFreq(void)
{
  return RCC_GetSysClockFreq_Private();
}

uint32_t HAL_RCC_GetHCLKFreq(void)
{
  return SystemCoreClock;
}

uint32_t HAL_RCC_GetPCLK1Freq(void)
{
  return (HAL_RCC_GetHCLKFreq() >> APBPrescTable[(RCC->CFGR & RCC_CFGR_PPRE1) >> 10]);
}

uint32_t HAL_RCC_GetPCLK2Freq(void)
{
  return (HAL_RCC_GetHCLKFreq() >> APBPrescTable[(RCC->CFGR & RCC_CFGR_PPRE2) >> 13]);
}
