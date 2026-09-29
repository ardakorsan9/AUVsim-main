//
// Academic License - for use in teaching, academic research, and meeting
// course requirements at degree granting institutions only.  Not for
// government, commercial, or other organizational use.
// File: _coder_auv_runtime_codegen_init_mex.h
//
// MATLAB Coder version            : 25.2
// C/C++ source code generated on  : 28-Aug-2026 17:25:48
//

#ifndef _CODER_AUV_RUNTIME_CODEGEN_INIT_MEX_H
#define _CODER_AUV_RUNTIME_CODEGEN_INIT_MEX_H

// Include Files
#include "emlrt.h"
#include "mex.h"
#include "tmwtypes.h"

// Function Declarations
MEXFUNCTION_LINKAGE void mexFunction(int32_T nlhs, mxArray *plhs[],
                                     int32_T nrhs, const mxArray *prhs[]);

emlrtCTX mexFunctionCreateRootTLS();

void unsafe_auv_runtime_codegen_init_mexFunction(int32_T nlhs, mxArray *plhs[1],
                                                 int32_T nrhs,
                                                 const mxArray *prhs[1]);

void unsafe_auv_runtime_codegen_reset_mexFunction(int32_T nlhs,
                                                  mxArray *plhs[1],
                                                  int32_T nrhs,
                                                  const mxArray *prhs[1]);

void unsafe_auv_runtime_codegen_step_mexFunction(int32_T nlhs, mxArray *plhs[2],
                                                 int32_T nrhs,
                                                 const mxArray *prhs[3]);

#endif
//
// File trailer for _coder_auv_runtime_codegen_init_mex.h
//
// [EOF]
//
