#ifndef AUV_PWM_MAPPER_H
#define AUV_PWM_MAPPER_H

/*
 * Pure validated logical-command -> PWM mapper.
 * Caller supplies per-channel calibration; no HAL/TIM/heap or default tuning.
 * PRETARGET DEPLOY_CANDIDATE / LOGICAL COMMANDS ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
 */

#include "auv_runtime_adapter.h"
#include "auv_safety_fsm.h"

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define AUV_PWM_MAPPER_ABS_MIN_US 1000U
#define AUV_PWM_MAPPER_ABS_MAX_US 2000U

typedef struct {
  double neutral_us;
  double min_us;
  double max_us;
  double scale;
  double direction;
} AuvPwmChannelConfig;

typedef struct {
  AuvPwmChannelConfig rudder;
  AuvPwmChannelConfig elevator;
  AuvPwmChannelConfig thrust;
} AuvPwmMapperConfig;

typedef struct {
  uint16_t rudder_us;
  uint16_t elevator_us;
  uint16_t thrust_us;
  bool publish;
  bool rudder_clamped;
  bool elevator_clamped;
  bool thrust_clamped;
} AuvPwmMapperOutput;

bool auv_pwm_mapper_validate_config(const AuvPwmMapperConfig *cfg);
void auv_pwm_mapper_zero(AuvPwmMapperOutput *out);
void auv_pwm_mapper_map(const AuvPwmMapperConfig *cfg,
                        AuvSafetyState safety_state,
                        const AuvRuntimeLogicalCmd *cmd,
                        AuvPwmMapperOutput *out);

#ifdef __cplusplus
}
#endif

#endif
