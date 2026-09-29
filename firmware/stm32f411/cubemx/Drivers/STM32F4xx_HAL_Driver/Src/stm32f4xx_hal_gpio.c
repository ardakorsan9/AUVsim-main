#include "stm32f4xx_hal.h"

void HAL_GPIO_Init(GPIO_TypeDef *GPIOx, GPIO_InitTypeDef *GPIO_Init)
{
  uint32_t position = 0U;
  uint32_t iocurrent;
  uint32_t temp;

  while (((GPIO_Init->Pin) >> position) != 0U)
  {
    iocurrent = (GPIO_Init->Pin) & (1UL << position);
    if (iocurrent != 0U)
    {
      /* Mode */
      temp = GPIOx->MODER;
      temp &= ~(3UL << (position * 2U));
      temp |= ((GPIO_Init->Mode & 0x3U) << (position * 2U));
      GPIOx->MODER = temp;

      if ((GPIO_Init->Mode == GPIO_MODE_OUTPUT_PP) || (GPIO_Init->Mode == GPIO_MODE_OUTPUT_OD) ||
          (GPIO_Init->Mode == GPIO_MODE_AF_PP) || (GPIO_Init->Mode == GPIO_MODE_AF_OD))
      {
        temp = GPIOx->OSPEEDR;
        temp &= ~(3UL << (position * 2U));
        temp |= (GPIO_Init->Speed << (position * 2U));
        GPIOx->OSPEEDR = temp;

        temp = GPIOx->OTYPER;
        temp &= ~(1UL << position);
        temp |= (((GPIO_Init->Mode & 0x10U) >> 4) << position);
        GPIOx->OTYPER = temp;
      }

      temp = GPIOx->PUPDR;
      temp &= ~(3UL << (position * 2U));
      temp |= ((GPIO_Init->Pull) << (position * 2U));
      GPIOx->PUPDR = temp;

      if ((GPIO_Init->Mode == GPIO_MODE_AF_PP) || (GPIO_Init->Mode == GPIO_MODE_AF_OD))
      {
        temp = GPIOx->AFR[position >> 3U];
        temp &= ~(0xFUL << ((position & 0x07U) * 4U));
        temp |= ((GPIO_Init->Alternate) << ((position & 0x07U) * 4U));
        GPIOx->AFR[position >> 3U] = temp;
      }
    }
    position++;
  }
}

void HAL_GPIO_DeInit(GPIO_TypeDef *GPIOx, uint32_t GPIO_Pin)
{
  uint32_t position = 0U;
  uint32_t iocurrent;
  while (((GPIO_Pin) >> position) != 0U)
  {
    iocurrent = (GPIO_Pin) & (1UL << position);
    if (iocurrent != 0U)
    {
      GPIOx->MODER &= ~(3UL << (position * 2U));
      GPIOx->AFR[position >> 3U] &= ~(0xFUL << ((position & 0x07U) * 4U));
      GPIOx->OSPEEDR &= ~(3UL << (position * 2U));
      GPIOx->OTYPER &= ~(1UL << position);
      GPIOx->PUPDR &= ~(3UL << (position * 2U));
    }
    position++;
  }
}

GPIO_PinState HAL_GPIO_ReadPin(GPIO_TypeDef *GPIOx, uint16_t GPIO_Pin)
{
  return (((GPIOx->IDR) & GPIO_Pin) != 0U) ? GPIO_PIN_SET : GPIO_PIN_RESET;
}

void HAL_GPIO_WritePin(GPIO_TypeDef *GPIOx, uint16_t GPIO_Pin, GPIO_PinState PinState)
{
  if (PinState != GPIO_PIN_RESET)
  {
    GPIOx->BSRR = GPIO_Pin;
  }
  else
  {
    GPIOx->BSRR = ((uint32_t)GPIO_Pin << 16U);
  }
}

void HAL_GPIO_TogglePin(GPIO_TypeDef *GPIOx, uint16_t GPIO_Pin)
{
  uint32_t odr = GPIOx->ODR;
  GPIOx->BSRR = ((odr & GPIO_Pin) << 16U) | (~odr & GPIO_Pin);
}
