#ifndef __CMSIS_GCC_H
#define __CMSIS_GCC_H

#ifndef   __ASM
  #define __ASM __asm
#endif
#ifndef   __INLINE
  #define __INLINE inline
#endif
#ifndef   __STATIC_INLINE
  #define __STATIC_INLINE static inline
#endif
#ifndef   __STATIC_FORCEINLINE
  #define __STATIC_FORCEINLINE __attribute__((always_inline)) static inline
#endif
#ifndef   __NO_RETURN
  #define __NO_RETURN __attribute__((__noreturn__))
#endif
#ifndef   __USED
  #define __USED __attribute__((used))
#endif
#ifndef   __WEAK
  #define __WEAK __attribute__((weak))
#endif
#ifndef   __PACKED
  #define __PACKED __attribute__((packed, aligned(1)))
#endif
#ifndef   __ALIGNED
  #define __ALIGNED(x) __attribute__((aligned(x)))
#endif

__STATIC_FORCEINLINE void __disable_irq(void) { __ASM volatile ("cpsid i" : : : "memory"); }
__STATIC_FORCEINLINE void __enable_irq(void)  { __ASM volatile ("cpsie i" : : : "memory"); }
__STATIC_FORCEINLINE void __DSB(void) { __ASM volatile ("dsb 0xF":::"memory"); }
__STATIC_FORCEINLINE void __ISB(void) { __ASM volatile ("isb 0xF":::"memory"); }
__STATIC_FORCEINLINE void __NOP(void) { __ASM volatile ("nop"); }

__STATIC_FORCEINLINE uint32_t __get_PRIMASK(void)
{
  uint32_t result;
  __ASM volatile ("MRS %0, primask" : "=r" (result));
  return result;
}
__STATIC_FORCEINLINE void __set_PRIMASK(uint32_t priMask)
{
  __ASM volatile ("MSR primask, %0" : : "r" (priMask) : "memory");
}

#endif /* __CMSIS_GCC_H */
