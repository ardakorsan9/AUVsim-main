#ifndef __STM32F4xx_HAL_PWR_H
#define __STM32F4xx_HAL_PWR_H

#ifdef __cplusplus
 extern "C" {
#endif

#include "stm32f4xx_hal_def.h"

#define PWR_REGULATOR_VOLTAGE_SCALE1  0x0000C000U

#define __HAL_PWR_VOLTAGESCALING_CONFIG(__REGULATOR__) do { \
  MODIFY_REG(PWR->CR, PWR_CR_VOS, (__REGULATOR__)); \
} while(0)

#include "stm32f4xx_hal_pwr_ex.h"

#ifdef __cplusplus
}
#endif

#endif /* __STM32F4xx_HAL_PWR_H */
