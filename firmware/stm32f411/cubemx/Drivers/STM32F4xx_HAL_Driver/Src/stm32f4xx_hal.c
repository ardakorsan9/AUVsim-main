#include "stm32f4xx_hal.h"

static volatile uint32_t uwTick;
static uint32_t uwTickFreq = 1U;

__WEAK void HAL_MspInit(void) {}
__WEAK void HAL_MspDeInit(void) {}

HAL_StatusTypeDef HAL_InitTick(uint32_t TickPriority);

HAL_StatusTypeDef HAL_Init(void)
{
  HAL_NVIC_SetPriorityGrouping(NVIC_PRIORITYGROUP_4);
  if (HAL_InitTick(TICK_INT_PRIORITY) != HAL_OK)
  {
    return HAL_ERROR;
  }
  HAL_MspInit();
  return HAL_OK;
}

HAL_StatusTypeDef HAL_DeInit(void)
{
  HAL_MspDeInit();
  return HAL_OK;
}

__WEAK HAL_StatusTypeDef HAL_InitTick(uint32_t TickPriority)
{
  if (SysTick_Config(SystemCoreClock / (1000U / uwTickFreq)) > 0U)
  {
    return HAL_ERROR;
  }
  HAL_NVIC_SetPriority(SysTick_IRQn, TickPriority, 0U);
  return HAL_OK;
}

__WEAK void HAL_IncTick(void)
{
  uwTick += uwTickFreq;
}

__WEAK uint32_t HAL_GetTick(void)
{
  return uwTick;
}

__WEAK void HAL_Delay(uint32_t Delay)
{
  uint32_t tickstart = HAL_GetTick();
  uint32_t wait = Delay;
  if (wait < HAL_MAX_DELAY)
  {
    wait += (uint32_t)uwTickFreq;
  }
  while ((HAL_GetTick() - tickstart) < wait) { }
}

void HAL_SuspendTick(void)
{
  SysTick->CTRL &= ~SysTick_CTRL_TICKINT_Msk;
}

void HAL_ResumeTick(void)
{
  SysTick->CTRL |= SysTick_CTRL_TICKINT_Msk;
}
