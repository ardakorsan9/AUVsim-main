#include "auv_watchdog_policy.h"

static bool auv_watchdog_policy_safety_state_known(AuvSafetyState state)
{
  return state == AUV_SAFETY_STATE_DISARMED ||
         state == AUV_SAFETY_STATE_ARMED ||
         state == AUV_SAFETY_STATE_KILLED;
}

bool auv_watchdog_policy_limits_valid(const AuvWatchdogPolicyLimits *limits)
{
  if (limits == 0) {
    return false;
  }

  if (limits->max_tick_age >= UINT32_MAX) {
    return false;
  }

  return limits->min_tick_age <= limits->max_tick_age;
}

void auv_watchdog_policy_decide(const AuvWatchdogPolicyLimits *limits,
                                const AuvWatchdogPolicyInputs *inputs,
                                AuvWatchdogPolicyOutputs *outputs)
{
  if (outputs != 0) {
    outputs->may_feed = false;
  }

  if (limits == 0 || inputs == 0 || outputs == 0) {
    return;
  }

  if (!auv_watchdog_policy_limits_valid(limits)) {
    return;
  }

  if (!inputs->tick_observation_valid) {
    return;
  }

  if (!inputs->safety_state_valid ||
      !auv_watchdog_policy_safety_state_known(inputs->safety_state)) {
    return;
  }

  if (!inputs->scheduler_progressed) {
    return;
  }

  if (inputs->scheduler_overrun || inputs->kill || inputs->critical_fault) {
    return;
  }

  if (inputs->safety_state != AUV_SAFETY_STATE_ARMED) {
    return;
  }

  if (inputs->observed_tick_age < limits->min_tick_age ||
      inputs->observed_tick_age > limits->max_tick_age) {
    return;
  }

  outputs->may_feed = true;
}
