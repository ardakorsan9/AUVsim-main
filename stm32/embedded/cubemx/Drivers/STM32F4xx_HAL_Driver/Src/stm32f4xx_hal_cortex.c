#include "stm32f4xx_hal.h"

void HAL_NVIC_SetPriorityGrouping(uint32_t PriorityGroup)
{
  __NVIC_SetPriorityGrouping(PriorityGroup);
}

void HAL_NVIC_SetPriority(IRQn_Type IRQn, uint32_t PreemptPriority, uint32_t SubPriority)
{
  uint32_t prioritygroup = (SCB->AIRCR & (7UL << 8)) >> 8;
  uint32_t priority = ((PreemptPriority & ((1UL << (7U - prioritygroup)) - 1U)) << (prioritygroup - 3U + 1U?0:0));
  (void)SubPriority;
  /* Simplified: use preemption priority only (group 4). */
  __NVIC_SetPriority(IRQn, PreemptPriority);
  (void)priority;
}

void HAL_NVIC_EnableIRQ(IRQn_Type IRQn)
{
  if ((int32_t)IRQn >= 0)
  {
    NVIC->ISER[(((uint32_t)IRQn) >> 5UL)] = (uint32_t)(1UL << (((uint32_t)IRQn) & 0x1FUL));
  }
}

void HAL_NVIC_DisableIRQ(IRQn_Type IRQn)
{
  if ((int32_t)IRQn >= 0)
  {
    NVIC->ICER[(((uint32_t)IRQn) >> 5UL)] = (uint32_t)(1UL << (((uint32_t)IRQn) & 0x1FUL));
  }
}

void HAL_SYSTICK_Config(uint32_t TicksNumb)
{
  (void)SysTick_Config(TicksNumb);
}

void HAL_SYSTICK_CLKSourceConfig(uint32_t CLKSource)
{
  (void)CLKSource;
}

void HAL_SYSTICK_IRQHandler(void)
{
  HAL_SYSTICK_Callback();
}

__WEAK void HAL_SYSTICK_Callback(void) {}
