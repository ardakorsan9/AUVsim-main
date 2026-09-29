#include "auv_safety_fsm.h"

static bool arm_prerequisites_met(const AuvSafetyInputs *inputs)
{
  return !inputs->kill &&
         !inputs->scheduler_overrun &&
         inputs->sample_valid &&
         inputs->runtime_valid &&
         inputs->config_valid;
}

void auv_safety_fsm_init(AuvSafetyFsm *fsm)
{
  if (fsm == 0) {
    return;
  }

  fsm->state = AUV_SAFETY_STATE_DISARMED;
}

void auv_safety_fsm_step(AuvSafetyFsm *fsm, const AuvSafetyInputs *inputs, AuvSafetyOutputs *outputs)
{
  if (fsm == 0 || inputs == 0 || outputs == 0) {
    return;
  }

  if (inputs->kill || inputs->critical_fault) {
    fsm->state = AUV_SAFETY_STATE_KILLED;
  } else if (fsm->state == AUV_SAFETY_STATE_KILLED) {
    if (inputs->reset_from_kill && !inputs->arm_request && !inputs->kill) {
      fsm->state = AUV_SAFETY_STATE_DISARMED;
    }
  } else if (fsm->state == AUV_SAFETY_STATE_ARMED) {
    if (!inputs->arm_request || !arm_prerequisites_met(inputs)) {
      fsm->state = AUV_SAFETY_STATE_DISARMED;
    }
  } else {
    if (inputs->arm_request && arm_prerequisites_met(inputs)) {
      fsm->state = AUV_SAFETY_STATE_ARMED;
    }
  }

  outputs->state = fsm->state;
  outputs->publish_allowed = (fsm->state == AUV_SAFETY_STATE_ARMED);
}
