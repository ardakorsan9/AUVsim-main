#ifndef __STM32F4xx_H
#define __STM32F4xx_H

#ifdef __cplusplus
 extern "C" {
#endif

#if defined(STM32F411xE)
  #include "stm32f411xe.h"
#else
  #error "Please select STM32F411xE in compiler defines"
#endif

typedef enum { RESET = 0, SET = !RESET } FlagStatus, ITStatus;
typedef enum { DISABLE = 0, ENABLE = !DISABLE } FunctionalState;
typedef enum { SUCCESS = 0, ERROR = !SUCCESS } ErrorStatus;

#define SET_BIT(REG, BIT)     ((REG) |= (BIT))
#define CLEAR_BIT(REG, BIT)   ((REG) &= ~(BIT))
#define READ_BIT(REG, BIT)    ((REG) & (BIT))
#define CLEAR_REG(REG)        ((REG) = (0x0))
#define WRITE_REG(REG, VAL)   ((REG) = (VAL))
#define READ_REG(REG)         ((REG))
#define MODIFY_REG(REG, CLEARMASK, SETMASK)  WRITE_REG((REG), (((READ_REG(REG)) & (~(CLEARMASK))) | (SETMASK)))

#ifdef __cplusplus
}
#endif

#endif /* __STM32F4xx_H */
