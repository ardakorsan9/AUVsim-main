#ifndef AUV_WATCHDOG_POLICY_H
#define AUV_WATCHDOG_POLICY_H

/*
 * HAL-free watchdog feed-decision policy.
 * Caller supplies freshness limits and observed tick age; no hardware feed or timing state.
 * PRETARGET DEPLOY_CANDIDATE / NOT_IN_PRODUCTION / NOT_CERTIFIED
 */

#include <stdbool.h>
#include <stdint.h>

#include "auv_safety_fsm.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  uint32_t min_tick_age;
  uint32_t max_tick_age;
} AuvWatchdogPolicyLimits;

typedef struct {
  bool scheduler_progressed;
  bool scheduler_overrun;
  bool kill;
  bool critical_fault;
  AuvSafetyState safety_state;
  bool safety_state_valid;
  uint32_t observed_tick_age;
  bool tick_observation_valid;
} AuvWatchdogPolicyInputs;

typedef struct {
  bool may_feed;
} AuvWatchdogPolicyOutputs;

bool auv_watchdog_policy_limits_valid(const AuvWatchdogPolicyLimits *limits);
void auv_watchdog_policy_decide(const AuvWatchdogPolicyLimits *limits,
                                  const AuvWatchdogPolicyInputs *inputs,
                                  AuvWatchdogPolicyOutputs *outputs);

#ifdef __cplusplus
}
#endif

#endif
