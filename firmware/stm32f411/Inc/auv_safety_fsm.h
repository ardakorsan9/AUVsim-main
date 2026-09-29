#ifndef AUV_SAFETY_FSM_H
#define AUV_SAFETY_FSM_H

/*
 * Pure fail-closed safety state machine: DISARMED / ARMED / KILLED.
 * No heap, HAL, GPIO, timers, PWM, watchdog feeding, or automatic rearm.
 * PRETARGET DEPLOY_CANDIDATE / NOT_IN_PRODUCTION / NOT_CERTIFIED
 */

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
  AUV_SAFETY_STATE_DISARMED = 0,
  AUV_SAFETY_STATE_ARMED = 1,
  AUV_SAFETY_STATE_KILLED = 2
} AuvSafetyState;

typedef struct {
  bool arm_request;
  bool kill;
  bool scheduler_overrun;
  bool sample_valid;
  bool runtime_valid;
  bool config_valid;
  bool critical_fault;
  bool reset_from_kill;
} AuvSafetyInputs;

typedef struct {
  AuvSafetyState state;
  bool publish_allowed;
} AuvSafetyOutputs;

typedef struct {
  AuvSafetyState state;
} AuvSafetyFsm;

void auv_safety_fsm_init(AuvSafetyFsm *fsm);
void auv_safety_fsm_step(AuvSafetyFsm *fsm, const AuvSafetyInputs *inputs, AuvSafetyOutputs *outputs);

#ifdef __cplusplus
}
#endif

#endif
