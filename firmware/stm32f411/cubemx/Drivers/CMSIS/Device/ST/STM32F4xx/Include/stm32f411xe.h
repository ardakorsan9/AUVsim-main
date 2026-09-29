#ifndef __STM32F411xE_H
#define __STM32F411xE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef enum
{
  NonMaskableInt_IRQn         = -14,
  MemoryManagement_IRQn       = -12,
  BusFault_IRQn               = -11,
  UsageFault_IRQn             = -10,
  SVCall_IRQn                 = -5,
  DebugMonitor_IRQn           = -4,
  PendSV_IRQn                 = -2,
  SysTick_IRQn                = -1,
  WWDG_IRQn                   = 0,
  PVD_IRQn                    = 1,
  TAMP_STAMP_IRQn             = 2,
  RTC_WKUP_IRQn               = 3,
  FLASH_IRQn                  = 4,
  RCC_IRQn                    = 5,
  EXTI0_IRQn                  = 6,
  EXTI1_IRQn                  = 7,
  EXTI2_IRQn                  = 8,
  EXTI3_IRQn                  = 9,
  EXTI4_IRQn                  = 10,
  DMA1_Stream0_IRQn           = 11,
  DMA1_Stream1_IRQn           = 12,
  DMA1_Stream2_IRQn           = 13,
  DMA1_Stream3_IRQn           = 14,
  DMA1_Stream4_IRQn           = 15,
  DMA1_Stream5_IRQn           = 16,
  DMA1_Stream6_IRQn           = 17,
  ADC_IRQn                    = 18,
  EXTI9_5_IRQn                = 23,
  TIM1_BRK_TIM9_IRQn          = 24,
  TIM1_UP_TIM10_IRQn          = 25,
  TIM1_TRG_COM_TIM11_IRQn     = 26,
  TIM1_CC_IRQn                = 27,
  TIM2_IRQn                   = 28,
  TIM3_IRQn                   = 29,
  TIM4_IRQn                   = 30,
  I2C1_EV_IRQn                = 31,
  I2C1_ER_IRQn                = 32,
  I2C2_EV_IRQn                = 33,
  I2C2_ER_IRQn                = 34,
  SPI1_IRQn                   = 35,
  SPI2_IRQn                   = 36,
  USART1_IRQn                 = 37,
  USART2_IRQn                 = 38,
  EXTI15_10_IRQn              = 40,
  RTC_Alarm_IRQn              = 41,
  OTG_FS_WKUP_IRQn            = 42,
  DMA1_Stream7_IRQn           = 47,
  SDIO_IRQn                   = 49,
  TIM5_IRQn                   = 50,
  SPI3_IRQn                   = 51,
  DMA2_Stream0_IRQn           = 56,
  DMA2_Stream1_IRQn           = 57,
  DMA2_Stream2_IRQn           = 58,
  DMA2_Stream3_IRQn           = 59,
  DMA2_Stream4_IRQn           = 60,
  OTG_FS_IRQn                 = 67,
  DMA2_Stream5_IRQn           = 68,
  DMA2_Stream6_IRQn           = 69,
  DMA2_Stream7_IRQn           = 70,
  USART6_IRQn                 = 71,
  I2C3_EV_IRQn                = 72,
  I2C3_ER_IRQn                = 73,
  FPU_IRQn                    = 81,
  SPI4_IRQn                   = 84,
  SPI5_IRQn                   = 85
} IRQn_Type;

#define __CM4_REV                 0x0001U
#define __MPU_PRESENT             1U
#define __NVIC_PRIO_BITS          4U
#define __Vendor_SysTickConfig    0U
#define __FPU_PRESENT             1U

#include "core_cm4.h"
#include "system_stm32f4xx.h"
#include <stdint.h>

typedef struct
{
  volatile uint32_t MODER;
  volatile uint32_t OTYPER;
  volatile uint32_t OSPEEDR;
  volatile uint32_t PUPDR;
  volatile uint32_t IDR;
  volatile uint32_t ODR;
  volatile uint32_t BSRR;
  volatile uint32_t LCKR;
  volatile uint32_t AFR[2];
} GPIO_TypeDef;

typedef struct
{
  volatile uint32_t CR;
  volatile uint32_t PLLCFGR;
  volatile uint32_t CFGR;
  volatile uint32_t CIR;
  volatile uint32_t AHB1RSTR;
  volatile uint32_t AHB2RSTR;
  uint32_t RESERVED0[2];
  volatile uint32_t APB1RSTR;
  volatile uint32_t APB2RSTR;
  uint32_t RESERVED1[2];
  volatile uint32_t AHB1ENR;
  volatile uint32_t AHB2ENR;
  uint32_t RESERVED2[2];
  volatile uint32_t APB1ENR;
  volatile uint32_t APB2ENR;
  uint32_t RESERVED3[2];
  volatile uint32_t AHB1LPENR;
  volatile uint32_t AHB2LPENR;
  uint32_t RESERVED4[2];
  volatile uint32_t APB1LPENR;
  volatile uint32_t APB2LPENR;
  uint32_t RESERVED5[2];
  volatile uint32_t BDCR;
  volatile uint32_t CSR;
  uint32_t RESERVED6[2];
  volatile uint32_t SSCGR;
  volatile uint32_t PLLI2SCFGR;
  uint32_t RESERVED7;
  volatile uint32_t DCKCFGR;
} RCC_TypeDef;

typedef struct
{
  volatile uint32_t ACR;
  volatile uint32_t KEYR;
  volatile uint32_t OPTKEYR;
  volatile uint32_t SR;
  volatile uint32_t CR;
  volatile uint32_t OPTCR;
  volatile uint32_t OPTCR1;
} FLASH_TypeDef;

typedef struct
{
  volatile uint32_t CR;
  volatile uint32_t CSR;
} PWR_TypeDef;

typedef struct
{
  volatile uint32_t CR1;
  volatile uint32_t CR2;
  volatile uint32_t SMCR;
  volatile uint32_t DIER;
  volatile uint32_t SR;
  volatile uint32_t EGR;
  volatile uint32_t CCMR1;
  volatile uint32_t CCMR2;
  volatile uint32_t CCER;
  volatile uint32_t CNT;
  volatile uint32_t PSC;
  volatile uint32_t ARR;
  volatile uint32_t RCR;
  volatile uint32_t CCR1;
  volatile uint32_t CCR2;
  volatile uint32_t CCR3;
  volatile uint32_t CCR4;
  volatile uint32_t BDTR;
  volatile uint32_t DCR;
  volatile uint32_t DMAR;
  volatile uint32_t OR;
} TIM_TypeDef;

typedef struct
{
  volatile uint32_t SR;
  volatile uint32_t DR;
  volatile uint32_t BRR;
  volatile uint32_t CR1;
  volatile uint32_t CR2;
  volatile uint32_t CR3;
  volatile uint32_t GTPR;
} USART_TypeDef;

typedef struct
{
  volatile uint32_t CR;
  volatile uint32_t NDTR;
  volatile uint32_t PAR;
  volatile uint32_t M0AR;
  volatile uint32_t M1AR;
  volatile uint32_t FCR;
} DMA_Stream_TypeDef;

typedef struct
{
  volatile uint32_t LISR;
  volatile uint32_t HISR;
  volatile uint32_t LIFCR;
  volatile uint32_t HIFCR;
} DMA_TypeDef;

#define PERIPH_BASE           0x40000000UL
#define AHB1PERIPH_BASE       (PERIPH_BASE + 0x00020000UL)
#define APB1PERIPH_BASE       PERIPH_BASE
#define APB2PERIPH_BASE       (PERIPH_BASE + 0x00010000UL)

#define GPIOA_BASE            (AHB1PERIPH_BASE + 0x0000UL)
#define GPIOB_BASE            (AHB1PERIPH_BASE + 0x0400UL)
#define GPIOC_BASE            (AHB1PERIPH_BASE + 0x0800UL)
#define GPIOH_BASE            (AHB1PERIPH_BASE + 0x1C00UL)
#define RCC_BASE              (AHB1PERIPH_BASE + 0x3800UL)
#define FLASH_R_BASE          (AHB1PERIPH_BASE + 0x3C00UL)
#define DMA1_BASE             (AHB1PERIPH_BASE + 0x6000UL)
#define DMA2_BASE             (AHB1PERIPH_BASE + 0x6400UL)
#define PWR_BASE              (APB1PERIPH_BASE + 0x7000UL)
#define TIM3_BASE             (APB1PERIPH_BASE + 0x0400UL)
#define USART1_BASE           (APB2PERIPH_BASE + 0x1000UL)

#define GPIOA                 ((GPIO_TypeDef *)GPIOA_BASE)
#define GPIOB                 ((GPIO_TypeDef *)GPIOB_BASE)
#define GPIOC                 ((GPIO_TypeDef *)GPIOC_BASE)
#define GPIOH                 ((GPIO_TypeDef *)GPIOH_BASE)
#define RCC                   ((RCC_TypeDef *)RCC_BASE)
#define FLASH                 ((FLASH_TypeDef *)FLASH_R_BASE)
#define PWR                   ((PWR_TypeDef *)PWR_BASE)
#define TIM3                  ((TIM_TypeDef *)TIM3_BASE)
#define USART1                ((USART_TypeDef *)USART1_BASE)
#define DMA1                  ((DMA_TypeDef *)DMA1_BASE)
#define DMA2                  ((DMA_TypeDef *)DMA2_BASE)

#define FLASH_BASE            0x08000000UL
#define SRAM_BASE             0x20000000UL

/* RCC bits */
#define RCC_CR_HSION          (1UL << 0)
#define RCC_CR_HSIRDY         (1UL << 1)
#define RCC_CR_HSEON          (1UL << 16)
#define RCC_CR_HSERDY         (1UL << 17)
#define RCC_CR_HSEBYP         (1UL << 18)
#define RCC_CR_PLLON          (1UL << 24)
#define RCC_CR_PLLRDY         (1UL << 25)

#define RCC_PLLCFGR_PLLM      0x0000003FUL
#define RCC_PLLCFGR_PLLN      0x00007FC0UL
#define RCC_PLLCFGR_PLLP      0x00030000UL
#define RCC_PLLCFGR_PLLSRC    (1UL << 22)
#define RCC_PLLCFGR_PLLSRC_HSE (1UL << 22)
#define RCC_PLLCFGR_PLLQ      0x0F000000UL

#define RCC_CFGR_SW           0x00000003UL
#define RCC_CFGR_SW_HSI       0x00000000UL
#define RCC_CFGR_SW_HSE       0x00000001UL
#define RCC_CFGR_SW_PLL       0x00000002UL
#define RCC_CFGR_SWS          0x0000000CUL
#define RCC_CFGR_SWS_HSI      0x00000000UL
#define RCC_CFGR_SWS_HSE      0x00000004UL
#define RCC_CFGR_SWS_PLL      0x00000008UL
#define RCC_CFGR_HPRE         0x000000F0UL
#define RCC_CFGR_PPRE1        0x00001C00UL
#define RCC_CFGR_PPRE2        0x0000E000UL

#define RCC_AHB1ENR_GPIOAEN   (1UL << 0)
#define RCC_AHB1ENR_GPIOBEN   (1UL << 1)
#define RCC_AHB1ENR_GPIOCEN   (1UL << 2)
#define RCC_AHB1ENR_GPIOHEN   (1UL << 7)
#define RCC_APB1ENR_TIM3EN    (1UL << 1)
#define RCC_APB1ENR_PWREN     (1UL << 28)
#define RCC_APB2ENR_USART1EN  (1UL << 4)

#define FLASH_ACR_LATENCY     0x0000000FUL
#define FLASH_ACR_LATENCY_3WS 0x00000003UL
#define FLASH_ACR_PRFTEN      (1UL << 8)
#define FLASH_ACR_ICEN        (1UL << 9)
#define FLASH_ACR_DCEN        (1UL << 10)

#define PWR_CR_VOS            (3UL << 14)

#define TIM_CR1_CEN           (1UL << 0)
#define TIM_CR1_ARPE          (1UL << 7)
#define TIM_CCER_CC1E         (1UL << 0)
#define TIM_CCER_CC2E         (1UL << 4)
#define TIM_CCER_CC3E         (1UL << 8)
#define TIM_CCMR1_OC1M        (7UL << 4)
#define TIM_CCMR1_OC1PE       (1UL << 3)
#define TIM_CCMR1_OC2M        (7UL << 12)
#define TIM_CCMR1_OC2PE       (1UL << 11)
#define TIM_CCMR2_OC3M        (7UL << 4)
#define TIM_CCMR2_OC3PE       (1UL << 3)
#define TIM_EGR_UG            (1UL << 0)

#define USART_SR_TXE          (1UL << 7)
#define USART_SR_RXNE         (1UL << 5)
#define USART_SR_TC           (1UL << 6)
#define USART_CR1_UE          (1UL << 13)
#define USART_CR1_TE          (1UL << 3)
#define USART_CR1_RE          (1UL << 2)
#define USART_CR1_OVER8       (1UL << 15)

#ifndef HSE_VALUE
#define HSE_VALUE 25000000U
#endif
#ifndef HSI_VALUE
#define HSI_VALUE 16000000U
#endif

#ifdef __cplusplus
}
#endif

#endif /* __STM32F411xE_H */
