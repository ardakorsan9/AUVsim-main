#ifndef __CORE_CM4_H_GENERIC
#define __CORE_CM4_H_GENERIC

#include <stdint.h>
#include "cmsis_version.h"

#if defined (__GNUC__)
  #define __ASM __asm
#else
  #error Unknown compiler
#endif

#include "cmsis_compiler.h"

#ifdef __cplusplus
 extern "C" {
#endif

#define __FPU_USED 1U

typedef struct
{
  volatile uint32_t CTRL;
  volatile uint32_t LOAD;
  volatile uint32_t VAL;
  volatile const uint32_t CALIB;
} SysTick_Type;

typedef struct
{
  volatile const uint32_t CPUID;
  volatile uint32_t ICSR;
  volatile uint32_t VTOR;
  volatile uint32_t AIRCR;
  volatile uint32_t SCR;
  volatile uint32_t CCR;
  volatile uint8_t  SHP[12U];
  volatile uint32_t SHCSR;
  volatile uint32_t CFSR;
  volatile uint32_t HFSR;
  volatile uint32_t DFSR;
  volatile uint32_t MMFAR;
  volatile uint32_t BFAR;
  volatile uint32_t AFSR;
  volatile const uint32_t PFR[2U];
  volatile const uint32_t DFR;
  volatile const uint32_t ADR;
  volatile const uint32_t MMFR[4U];
  volatile const uint32_t ISAR[5U];
  uint32_t RESERVED0[5U];
  volatile uint32_t CPACR;
} SCB_Type;

typedef struct
{
  volatile uint32_t ISER[8U];
  uint32_t RESERVED0[24U];
  volatile uint32_t ICER[8U];
  uint32_t RESERVED1[24U];
  volatile uint32_t ISPR[8U];
  uint32_t RESERVED2[24U];
  volatile uint32_t ICPR[8U];
  uint32_t RESERVED3[24U];
  volatile uint32_t IABR[8U];
  uint32_t RESERVED4[56U];
  volatile uint8_t  IP[240U];
  uint32_t RESERVED5[644U];
  volatile  uint32_t STIR;
} NVIC_Type;

#define SCS_BASE            (0xE000E000UL)
#define SysTick_BASE        (SCS_BASE + 0x0010UL)
#define NVIC_BASE           (SCS_BASE + 0x0100UL)
#define SCB_BASE            (SCS_BASE + 0x0D00UL)

#define SCB                 ((SCB_Type *)SCB_BASE)
#define SysTick             ((SysTick_Type *)SysTick_BASE)
#define NVIC                ((NVIC_Type *)NVIC_BASE)

#define SysTick_CTRL_COUNTFLAG_Msk (1UL << 16)
#define SysTick_CTRL_CLKSOURCE_Msk (1UL << 2)
#define SysTick_CTRL_TICKINT_Msk   (1UL << 1)
#define SysTick_CTRL_ENABLE_Msk    (1UL << 0)

#define SCB_AIRCR_VECTKEY_Pos      16U
#define SCB_AIRCR_PRIGROUP_Pos      8U
#define SCB_AIRCR_SYSRESETREQ_Msk  (1UL << 2)

__STATIC_INLINE void __NVIC_SetPriorityGrouping(uint32_t PriorityGroup)
{
  uint32_t reg = SCB->AIRCR;
  reg &= ~((uint32_t)(0xFFFFUL << 16) | (7UL << 8));
  reg |= ((uint32_t)0x5FAUL << 16) | ((PriorityGroup & 7UL) << 8);
  SCB->AIRCR = reg;
}

__STATIC_INLINE void __NVIC_SetPriority(IRQn_Type IRQn, uint32_t priority)
{
  if ((int32_t)IRQn >= 0)
  {
    NVIC->IP[((uint32_t)IRQn)] = (uint8_t)((priority << (8U - __NVIC_PRIO_BITS)) & 0xFFUL);
  }
  else
  {
    SCB->SHP[(((uint32_t)IRQn) & 0xFUL) - 4UL] =
      (uint8_t)((priority << (8U - __NVIC_PRIO_BITS)) & 0xFFUL);
  }
}

__STATIC_INLINE uint32_t SysTick_Config(uint32_t ticks)
{
  if ((ticks - 1UL) > 0xFFFFFFUL) { return 1UL; }
  SysTick->LOAD = ticks - 1UL;
  __NVIC_SetPriority(SysTick_IRQn, (1UL << __NVIC_PRIO_BITS) - 1UL);
  SysTick->VAL = 0UL;
  SysTick->CTRL = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_TICKINT_Msk | SysTick_CTRL_ENABLE_Msk;
  return 0UL;
}

#ifdef __cplusplus
}
#endif

#endif /* __CORE_CM4_H_GENERIC */
