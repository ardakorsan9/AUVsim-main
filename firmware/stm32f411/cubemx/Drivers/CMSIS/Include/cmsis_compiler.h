#ifndef __CMSIS_COMPILER_H
#define __CMSIS_COMPILER_H
#include <stdint.h>
#if defined (__GNUC__)
  #include "cmsis_gcc.h"
#else
  #error "Compiler not supported"
#endif
#endif
