#ifndef __STM32F4xx_HAL_TIM_EX_H
#define __STM32F4xx_HAL_TIM_EX_H

#ifdef __cplusplus
 extern "C" {
#endif

#include "stm32f4xx_hal_def.h"

HAL_StatusTypeDef HAL_TIMEx_MasterConfigSynchronization(TIM_HandleTypeDef *htim, TIM_MasterConfigTypeDef *sMasterConfig);

#ifdef __cplusplus
}
#endif

#endif /* __STM32F4xx_HAL_TIM_EX_H */
