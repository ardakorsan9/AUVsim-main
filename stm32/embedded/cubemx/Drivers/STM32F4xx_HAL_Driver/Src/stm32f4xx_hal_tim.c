#include "stm32f4xx_hal.h"

__WEAK void HAL_TIM_Base_MspInit(TIM_HandleTypeDef *htim) { (void)htim; }
__WEAK void HAL_TIM_Base_MspDeInit(TIM_HandleTypeDef *htim) { (void)htim; }

static void TIM_Base_SetConfig(TIM_TypeDef *TIMx, TIM_Base_InitTypeDef *Structure)
{
  uint32_t tmpcr1 = TIMx->CR1;
  tmpcr1 &= ~(TIM_CR1_ARPE);
  tmpcr1 |= Structure->AutoReloadPreload;
  TIMx->CR1 = tmpcr1;
  TIMx->ARR = Structure->Period;
  TIMx->PSC = Structure->Prescaler;
  TIMx->EGR = TIM_EGR_UG;
}

HAL_StatusTypeDef HAL_TIM_Base_Init(TIM_HandleTypeDef *htim)
{
  if (htim == NULL)
  {
    return HAL_ERROR;
  }
  if (htim->State == HAL_TIM_STATE_RESET)
  {
    htim->Lock = HAL_UNLOCKED;
    HAL_TIM_Base_MspInit(htim);
  }
  htim->State = HAL_TIM_STATE_BUSY;
  TIM_Base_SetConfig(htim->Instance, &htim->Init);
  htim->State = HAL_TIM_STATE_READY;
  return HAL_OK;
}

HAL_StatusTypeDef HAL_TIM_Base_DeInit(TIM_HandleTypeDef *htim)
{
  htim->State = HAL_TIM_STATE_BUSY;
  __HAL_RCC_TIM3_CLK_DISABLE();
  HAL_TIM_Base_MspDeInit(htim);
  htim->State = HAL_TIM_STATE_RESET;
  __HAL_UNLOCK(htim);
  return HAL_OK;
}

HAL_StatusTypeDef HAL_TIM_ConfigClockSource(TIM_HandleTypeDef *htim, TIM_ClockConfigTypeDef *sClockSourceConfig)
{
  (void)sClockSourceConfig;
  if (htim == NULL)
  {
    return HAL_ERROR;
  }
  return HAL_OK;
}

HAL_StatusTypeDef HAL_TIM_PWM_Init(TIM_HandleTypeDef *htim)
{
  if (htim == NULL)
  {
    return HAL_ERROR;
  }
  return HAL_OK;
}

HAL_StatusTypeDef HAL_TIM_PWM_ConfigChannel(TIM_HandleTypeDef *htim, TIM_OC_InitTypeDef *sConfig, uint32_t Channel)
{
  if ((htim == NULL) || (sConfig == NULL))
  {
    return HAL_ERROR;
  }

  if (Channel == TIM_CHANNEL_1)
  {
    htim->Instance->CCMR1 &= ~(TIM_CCMR1_OC1M | TIM_CCMR1_OC1PE);
    htim->Instance->CCMR1 |= (sConfig->OCMode | TIM_CCMR1_OC1PE);
    htim->Instance->CCR1 = sConfig->Pulse;
    htim->Instance->CCER &= ~(TIM_CCER_CC1E);
  }
  else if (Channel == TIM_CHANNEL_2)
  {
    htim->Instance->CCMR1 &= ~(TIM_CCMR1_OC2M | TIM_CCMR1_OC2PE);
    htim->Instance->CCMR1 |= ((sConfig->OCMode << 8) | TIM_CCMR1_OC2PE);
    htim->Instance->CCR2 = sConfig->Pulse;
    htim->Instance->CCER &= ~(TIM_CCER_CC2E);
  }
  else if (Channel == TIM_CHANNEL_3)
  {
    htim->Instance->CCMR2 &= ~(TIM_CCMR2_OC3M | TIM_CCMR2_OC3PE);
    htim->Instance->CCMR2 |= (sConfig->OCMode | TIM_CCMR2_OC3PE);
    htim->Instance->CCR3 = sConfig->Pulse;
    htim->Instance->CCER &= ~(TIM_CCER_CC3E);
  }
  else
  {
    return HAL_ERROR;
  }

  return HAL_OK;
}

HAL_StatusTypeDef HAL_TIM_PWM_Start(TIM_HandleTypeDef *htim, uint32_t Channel)
{
  if (Channel == TIM_CHANNEL_1)
  {
    htim->Instance->CCER |= TIM_CCER_CC1E;
  }
  else if (Channel == TIM_CHANNEL_2)
  {
    htim->Instance->CCER |= TIM_CCER_CC2E;
  }
  else if (Channel == TIM_CHANNEL_3)
  {
    htim->Instance->CCER |= TIM_CCER_CC3E;
  }
  else
  {
    return HAL_ERROR;
  }

  htim->Instance->CR1 |= TIM_CR1_CEN;
  return HAL_OK;
}
