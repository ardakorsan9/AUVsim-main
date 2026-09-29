#ifndef __STM32F4xx_HAL_RCC_H
#define __STM32F4xx_HAL_RCC_H

#ifdef __cplusplus
 extern "C" {
#endif

#include "stm32f4xx_hal_def.h"

#define RCC_OSCILLATORTYPE_NONE            0x00000000U
#define RCC_OSCILLATORTYPE_HSE             0x00000001U
#define RCC_OSCILLATORTYPE_HSI             0x00000002U
#define RCC_HSE_OFF                        0x00000000U
#define RCC_HSE_ON                         0x00000001U
#define RCC_HSE_BYPASS                     0x00000005U
#define RCC_PLL_NONE                       0x00000000U
#define RCC_PLL_OFF                        0x00000001U
#define RCC_PLL_ON                         0x00000002U
#define RCC_PLLSOURCE_HSI                  0x00000000U
#define RCC_PLLSOURCE_HSE                  RCC_PLLCFGR_PLLSRC_HSE
#define RCC_PLLP_DIV2                      0x00000002U
#define RCC_PLLP_DIV4                      0x00000004U
#define RCC_PLLP_DIV6                      0x00000006U
#define RCC_PLLP_DIV8                      0x00000008U

#define RCC_CLOCKTYPE_SYSCLK               0x00000001U
#define RCC_CLOCKTYPE_HCLK                 0x00000002U
#define RCC_CLOCKTYPE_PCLK1                0x00000004U
#define RCC_CLOCKTYPE_PCLK2                0x00000008U

#define RCC_SYSCLKSOURCE_HSI               RCC_CFGR_SW_HSI
#define RCC_SYSCLKSOURCE_HSE               RCC_CFGR_SW_HSE
#define RCC_SYSCLKSOURCE_PLLCLK            RCC_CFGR_SW_PLL

#define RCC_SYSCLK_DIV1                    0x00000000U
#define RCC_HCLK_DIV1                      0x00000000U
#define RCC_HCLK_DIV2                      0x00001000U
#define RCC_HCLK_DIV4                      0x00001400U
#define RCC_HCLK_DIV8                      0x00001C00U
#define RCC_HCLK_DIV16                     0x00001C00U

typedef struct
{
  uint32_t PLLState;
  uint32_t PLLSource;
  uint32_t PLLM;
  uint32_t PLLN;
  uint32_t PLLP;
  uint32_t PLLQ;
} RCC_PLLInitTypeDef;

typedef struct
{
  uint32_t OscillatorType;
  uint32_t HSEState;
  uint32_t LSEState;
  uint32_t HSIState;
  uint32_t LSIState;
  RCC_PLLInitTypeDef PLL;
} RCC_OscInitTypeDef;

typedef struct
{
  uint32_t ClockType;
  uint32_t SYSCLKSource;
  uint32_t AHBCLKDivider;
  uint32_t APB1CLKDivider;
  uint32_t APB2CLKDivider;
} RCC_ClkInitTypeDef;

#define __HAL_RCC_GPIOA_CLK_ENABLE()   do { SET_BIT(RCC->AHB1ENR, RCC_AHB1ENR_GPIOAEN); } while(0)
#define __HAL_RCC_GPIOB_CLK_ENABLE()   do { SET_BIT(RCC->AHB1ENR, RCC_AHB1ENR_GPIOBEN); } while(0)
#define __HAL_RCC_GPIOC_CLK_ENABLE()   do { SET_BIT(RCC->AHB1ENR, RCC_AHB1ENR_GPIOCEN); } while(0)
#define __HAL_RCC_GPIOH_CLK_ENABLE()   do { SET_BIT(RCC->AHB1ENR, RCC_AHB1ENR_GPIOHEN); } while(0)
#define __HAL_RCC_TIM3_CLK_ENABLE()    do { SET_BIT(RCC->APB1ENR, RCC_APB1ENR_TIM3EN); } while(0)
#define __HAL_RCC_TIM3_CLK_DISABLE()   do { CLEAR_BIT(RCC->APB1ENR, RCC_APB1ENR_TIM3EN); } while(0)
#define __HAL_RCC_USART1_CLK_ENABLE()  do { SET_BIT(RCC->APB2ENR, RCC_APB2ENR_USART1EN); } while(0)
#define __HAL_RCC_USART1_CLK_DISABLE() do { CLEAR_BIT(RCC->APB2ENR, RCC_APB2ENR_USART1EN); } while(0)
#define __HAL_RCC_PWR_CLK_ENABLE()     do { SET_BIT(RCC->APB1ENR, RCC_APB1ENR_PWREN); } while(0)

HAL_StatusTypeDef HAL_RCC_OscConfig(RCC_OscInitTypeDef *RCC_OscInitStruct);
HAL_StatusTypeDef HAL_RCC_ClockConfig(RCC_ClkInitTypeDef *RCC_ClkInitStruct, uint32_t FLatency);
uint32_t HAL_RCC_GetSysClockFreq(void);
uint32_t HAL_RCC_GetHCLKFreq(void);
uint32_t HAL_RCC_GetPCLK1Freq(void);
uint32_t HAL_RCC_GetPCLK2Freq(void);

#include "stm32f4xx_hal_rcc_ex.h"

#ifdef __cplusplus
}
#endif

#endif /* __STM32F4xx_HAL_RCC_H */
