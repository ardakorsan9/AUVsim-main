#include "stm32f4xx_hal.h"

__WEAK void HAL_UART_MspInit(UART_HandleTypeDef *huart) { (void)huart; }
__WEAK void HAL_UART_MspDeInit(UART_HandleTypeDef *huart) { (void)huart; }

HAL_StatusTypeDef HAL_UART_Init(UART_HandleTypeDef *huart)
{
  uint32_t pclk;
  uint32_t div;

  if (huart == NULL)
  {
    return HAL_ERROR;
  }

  if (huart->gState == HAL_UART_STATE_RESET)
  {
    huart->Lock = HAL_UNLOCKED;
    HAL_UART_MspInit(huart);
  }

  huart->gState = HAL_UART_STATE_BUSY;

  CLEAR_BIT(huart->Instance->CR1, USART_CR1_UE);

  pclk = HAL_RCC_GetPCLK2Freq();
  div = (pclk + (huart->Init.BaudRate / 2U)) / huart->Init.BaudRate;
  huart->Instance->BRR = div;

  WRITE_REG(huart->Instance->CR2, 0U);
  WRITE_REG(huart->Instance->CR3, 0U);
  WRITE_REG(huart->Instance->CR1, huart->Init.Mode);

  SET_BIT(huart->Instance->CR1, USART_CR1_UE);

  huart->gState = HAL_UART_STATE_READY;
  huart->RxState = HAL_UART_STATE_READY;
  return HAL_OK;
}

HAL_StatusTypeDef HAL_UART_DeInit(UART_HandleTypeDef *huart)
{
  if (huart == NULL)
  {
    return HAL_ERROR;
  }
  CLEAR_BIT(huart->Instance->CR1, USART_CR1_UE);
  HAL_UART_MspDeInit(huart);
  huart->gState = HAL_UART_STATE_RESET;
  huart->RxState = HAL_UART_STATE_RESET;
  __HAL_UNLOCK(huart);
  return HAL_OK;
}
