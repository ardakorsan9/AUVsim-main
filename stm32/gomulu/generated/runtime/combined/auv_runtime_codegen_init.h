//
// Academic License - for use in teaching, academic research, and meeting
// course requirements at degree granting institutions only.  Not for
// government, commercial, or other organizational use.
// File: auv_runtime_codegen_init.h
//
// MATLAB Coder version            : 25.2
// C/C++ source code generated on  : 28-Aug-2026 17:25:48
//

#ifndef AUV_RUNTIME_CODEGEN_INIT_H
#define AUV_RUNTIME_CODEGEN_INIT_H

// Include Files
#include "rtwtypes.h"
#include <cstddef>
#include <cstdlib>

// Type Declarations
struct struct0_T;

struct struct5_T;

struct struct9_T;

struct struct15_T;

struct struct17_T;

// Function Declarations
extern void auv_runtime_codegen_init(const struct0_T *cfg, struct5_T *params);

extern void auv_runtime_codegen_init_initialize();

extern void auv_runtime_codegen_init_terminate();

extern void auv_runtime_codegen_reset(const struct5_T *params,
                                      struct9_T *state);

extern void auv_runtime_codegen_step(const struct5_T *params, struct9_T *state,
                                     const struct15_T *in, struct17_T *out);

#endif
//
// File trailer for auv_runtime_codegen_init.h
//
// [EOF]
//
