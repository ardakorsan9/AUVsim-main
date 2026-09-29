#ifndef __STM32F4xx_HAL_TIM_H
#define __STM32F4xx_HAL_TIM_H

#ifdef __cplusplus
 extern "C" {
#endif

#include "stm32f4xx_hal_def.h"

typedef struct
{
  uint32_t Prescaler;
  uint32_t CounterMode;
  uint32_t Period;
  uint32_t ClockDivision;
  uint32_t RepetitionCounter;
  uint32_t AutoReloadPreload;
} TIM_Base_InitTypeDef;

typedef struct
{
  uint32_t ClockSource;
} TIM_ClockConfigTypeDef;

typedef struct
{
  uint32_t OCMode;
  uint32_t Pulse;
  uint32_t OCPolarity;
  uint32_t OCNPolarity;
  uint32_t OCFastMode;
  uint32_t OCIdleState;
  uint32_t OCNIdleState;
} TIM_OC_InitTypeDef;

typedef struct
{
  uint32_t MasterOutputTrigger;
  uint32_t MasterSlaveMode;
} TIM_MasterConfigTypeDef;

typedef enum
{
  HAL_TIM_STATE_RESET             = 0x00U,
  HAL_TIM_STATE_READY             = 0x01U,
  HAL_TIM_STATE_BUSY              = 0x02U,
  HAL_TIM_STATE_TIMEOUT           = 0x03U,
  HAL_TIM_STATE_ERROR             = 0x04U
} HAL_TIM_StateTypeDef;

typedef struct
{
  TIM_TypeDef                 *Instance;
  TIM_Base_InitTypeDef         Init;
  HAL_TIM_StateTypeDef         State;
  HAL_LockTypeDef              Lock;
} TIM_HandleTypeDef;

#define TIM_COUNTERMODE_UP                 0x00000000U
#define TIM_CLOCKDIVISION_DIV1             0x00000000U
#define TIM_AUTORELOAD_PRELOAD_DISABLE     0x00000000U
#define TIM_AUTORELOAD_PRELOAD_ENABLE      TIM_CR1_ARPE
#define TIM_CLOCKSOURCE_INTERNAL           0x00000001U
#define TIM_OCMODE_PWM1                    0x00000060U
#define TIM_OCPOLARITY_HIGH                0x00000000U
#define TIM_OCFAST_DISABLE                 0x00000000U
#define TIM_TRGO_RESET                     0x00000000U
#define TIM_MASTERSLAVEMODE_DISABLE        0x00000000U

#define TIM_CHANNEL_1                      0x00000000U
#define TIM_CHANNEL_2                      0x00000004U
#define TIM_CHANNEL_3                      0x00000008U
#define TIM_CHANNEL_4                      0x0000000CU

#define __HAL_TIM_SET_COMPARE(__HANDLE__, __CHANNEL__, __COMPARE__) \
  (((__CHANNEL__) == TIM_CHANNEL_1) ? ((__HANDLE__)->Instance->CCR1 = (__COMPARE__)) : \
   ((__CHANNEL__) == TIM_CHANNEL_2) ? ((__HANDLE__)->Instance->CCR2 = (__COMPARE__)) : \
   ((__CHANNEL__) == TIM_CHANNEL_3) ? ((__HANDLE__)->Instance->CCR3 = (__COMPARE__)) : \
                                      ((__HANDLE__)->Instance->CCR4 = (__COMPARE__)))

HAL_StatusTypeDef HAL_TIM_Base_Init(TIM_HandleTypeDef *htim);
HAL_StatusTypeDef HAL_TIM_Base_DeInit(TIM_HandleTypeDef *htim);
void HAL_TIM_Base_MspInit(TIM_HandleTypeDef *htim);
void HAL_TIM_Base_MspDeInit(TIM_HandleTypeDef *htim);
HAL_StatusTypeDef HAL_TIM_ConfigClockSource(TIM_HandleTypeDef *htim, TIM_ClockConfigTypeDef *sClockSourceConfig);
HAL_StatusTypeDef HAL_TIM_PWM_Init(TIM_HandleTypeDef *htim);
HAL_StatusTypeDef HAL_TIM_PWM_ConfigChannel(TIM_HandleTypeDef *htim, TIM_OC_InitTypeDef *sConfig, uint32_t Channel);
HAL_StatusTypeDef HAL_TIM_PWM_Start(TIM_HandleTypeDef *htim, uint32_t Channel);

#include "stm32f4xx_hal_tim_ex.h"

#ifdef __cplusplus
}
#endif

#endif /* __STM32F4xx_HAL_TIM_H */
