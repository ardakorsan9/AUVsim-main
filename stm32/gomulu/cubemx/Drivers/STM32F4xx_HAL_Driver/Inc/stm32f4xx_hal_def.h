#ifndef __STM32F4xx_HAL_DEF_H
#define __STM32F4xx_HAL_DEF_H

#include "stm32f4xx.h"
#include <stddef.h>

#ifndef NULL
#define NULL 0
#endif

#define UNUSED(x) ((void)(x))

typedef enum
{
  HAL_OK       = 0x00U,
  HAL_ERROR    = 0x01U,
  HAL_BUSY     = 0x02U,
  HAL_TIMEOUT  = 0x03U
} HAL_StatusTypeDef;

typedef enum
{
  HAL_UNLOCKED = 0x00U,
  HAL_LOCKED   = 0x01U
} HAL_LockTypeDef;

#define HAL_MAX_DELAY      0xFFFFFFFFU

#define __HAL_LOCK(__HANDLE__)             \
  do {                                     \
    if ((__HANDLE__)->Lock == HAL_LOCKED)  \
    {                                      \
      return HAL_BUSY;                     \
    }                                      \
    else                                   \
    {                                      \
      (__HANDLE__)->Lock = HAL_LOCKED;     \
    }                                      \
  } while (0U)

#define __HAL_UNLOCK(__HANDLE__)           \
  do {                                     \
    (__HANDLE__)->Lock = HAL_UNLOCKED;     \
  } while (0U)

#endif /* __STM32F4xx_HAL_DEF_H */
