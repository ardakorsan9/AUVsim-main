#ifndef AUV_RUNTIME_ADAPTER_H
#define AUV_RUNTIME_ADAPTER_H

/*
 * Pure fail-closed adapter: AuvRuntimeOut -> logical actuator command.
 * No heap, HAL, PWM, calibration, state machine, or runtime invocation.
 * PRETARGET DEPLOY_CANDIDATE / LOGICAL COMMANDS ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
 */

#include "auv_runtime_port.h"

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  double delta_r;
  double delta_e;
  double thrust;
  bool valid;
} AuvRuntimeLogicalCmd;

void auv_runtime_adapter_zero(AuvRuntimeLogicalCmd *cmd);
bool auv_runtime_adapter_update(const AuvRuntimeOut *out, AuvRuntimeLogicalCmd *cmd);

#ifdef __cplusplus
}
#endif

#endif
