#ifndef __STM32F4xx_HAL_DMA_H
#define __STM32F4xx_HAL_DMA_H

#ifdef __cplusplus
 extern "C" {
#endif

#include "stm32f4xx_hal_def.h"

typedef struct __DMA_HandleTypeDef
{
  void *Instance;
  HAL_LockTypeDef Lock;
  void (* XferCpltCallback)(struct __DMA_HandleTypeDef *hdma);
} DMA_HandleTypeDef;

#ifdef __cplusplus
}
#endif

#endif /* __STM32F4xx_HAL_DMA_H */
