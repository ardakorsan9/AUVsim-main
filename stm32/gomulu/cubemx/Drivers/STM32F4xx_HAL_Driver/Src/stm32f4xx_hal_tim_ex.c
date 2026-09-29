#include "stm32f4xx_hal.h"

HAL_StatusTypeDef HAL_TIMEx_MasterConfigSynchronization(TIM_HandleTypeDef *htim, TIM_MasterConfigTypeDef *sMasterConfig)
{
  if ((htim == NULL) || (sMasterConfig == NULL))
  {
    return HAL_ERROR;
  }
  (void)sMasterConfig->MasterOutputTrigger;
  (void)sMasterConfig->MasterSlaveMode;
  return HAL_OK;
}
