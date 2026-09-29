#ifndef __STM32F4xx_HAL_UART_H
#define __STM32F4xx_HAL_UART_H

#ifdef __cplusplus
 extern "C" {
#endif

#include "stm32f4xx_hal_def.h"

typedef struct
{
  uint32_t BaudRate;
  uint32_t WordLength;
  uint32_t StopBits;
  uint32_t Parity;
  uint32_t Mode;
  uint32_t HwFlowCtl;
  uint32_t OverSampling;
} UART_InitTypeDef;

typedef enum
{
  HAL_UART_STATE_RESET             = 0x00U,
  HAL_UART_STATE_READY             = 0x20U,
  HAL_UART_STATE_BUSY              = 0x24U,
  HAL_UART_STATE_BUSY_TX           = 0x21U,
  HAL_UART_STATE_BUSY_RX           = 0x22U,
  HAL_UART_STATE_BUSY_TX_RX        = 0x23U,
  HAL_UART_STATE_TIMEOUT           = 0xA0U,
  HAL_UART_STATE_ERROR             = 0xE0U
} HAL_UART_StateTypeDef;

typedef struct __UART_HandleTypeDef
{
  USART_TypeDef            *Instance;
  UART_InitTypeDef          Init;
  HAL_LockTypeDef           Lock;
  HAL_UART_StateTypeDef     gState;
  HAL_UART_StateTypeDef     RxState;
} UART_HandleTypeDef;

#define UART_WORDLENGTH_8B                  0x00000000U
#define UART_STOPBITS_1                     0x00000000U
#define UART_PARITY_NONE                    0x00000000U
#define UART_MODE_TX_RX                     (USART_CR1_TE | USART_CR1_RE)
#define UART_HWCONTROL_NONE                 0x00000000U
#define UART_OVERSAMPLING_16                0x00000000U

HAL_StatusTypeDef HAL_UART_Init(UART_HandleTypeDef *huart);
HAL_StatusTypeDef HAL_UART_DeInit(UART_HandleTypeDef *huart);
void HAL_UART_MspInit(UART_HandleTypeDef *huart);
void HAL_UART_MspDeInit(UART_HandleTypeDef *huart);

#ifdef __cplusplus
}
#endif

#endif /* __STM32F4xx_HAL_UART_H */
