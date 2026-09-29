/*
 * Pure validated logical-command -> PWM mapper.
 * PRETARGET DEPLOY_CANDIDATE / LOGICAL COMMANDS ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
 */

#include "auv_pwm_mapper.h"

#include <cmath>

namespace {

constexpr double kAbsMinUs = static_cast<double>(AUV_PWM_MAPPER_ABS_MIN_US);
constexpr double kAbsMaxUs = static_cast<double>(AUV_PWM_MAPPER_ABS_MAX_US);

bool is_finite(double value)
{
  return std::isfinite(value);
}

bool channel_config_valid(const AuvPwmChannelConfig *channel)
{
  if (channel == 0) {
    return false;
  }
  if (!is_finite(channel->neutral_us) ||
      !is_finite(channel->min_us) ||
      !is_finite(channel->max_us) ||
      !is_finite(channel->scale) ||
      !is_finite(channel->direction)) {
    return false;
  }
  if (channel->min_us < kAbsMinUs || channel->max_us > kAbsMaxUs) {
    return false;
  }
  if (channel->neutral_us < kAbsMinUs || channel->neutral_us > kAbsMaxUs) {
    return false;
  }
  if (channel->min_us > channel->neutral_us || channel->neutral_us > channel->max_us) {
    return false;
  }
  return true;
}

uint16_t to_pwm_us(double value)
{
  if (value < 0.0) {
    value = 0.0;
  }
  if (value > 65535.0) {
    value = 65535.0;
  }
  return static_cast<uint16_t>(value + 0.5);
}

void set_neutral_output(const AuvPwmMapperConfig *cfg, AuvPwmMapperOutput *out)
{
  out->rudder_us = to_pwm_us(cfg->rudder.neutral_us);
  out->elevator_us = to_pwm_us(cfg->elevator.neutral_us);
  out->thrust_us = to_pwm_us(cfg->thrust.neutral_us);
  out->publish = false;
  out->rudder_clamped = false;
  out->elevator_clamped = false;
  out->thrust_clamped = false;
}

bool command_finite(const AuvRuntimeLogicalCmd *cmd)
{
  return is_finite(cmd->delta_r) && is_finite(cmd->delta_e) && is_finite(cmd->thrust);
}

void map_channel(const AuvPwmChannelConfig *channel,
                 double logical,
                 uint16_t *pwm_us,
                 bool *clamped)
{
  const double raw = channel->neutral_us + (channel->direction * channel->scale * logical);
  double value = raw;
  bool was_clamped = false;

  if (value < channel->min_us) {
    value = channel->min_us;
    was_clamped = true;
  } else if (value > channel->max_us) {
    value = channel->max_us;
    was_clamped = true;
  }

  *pwm_us = to_pwm_us(value);
  *clamped = was_clamped;
}

}  // namespace

bool auv_pwm_mapper_validate_config(const AuvPwmMapperConfig *cfg)
{
  if (cfg == 0) {
    return false;
  }
  return channel_config_valid(&cfg->rudder) &&
         channel_config_valid(&cfg->elevator) &&
         channel_config_valid(&cfg->thrust);
}

void auv_pwm_mapper_zero(AuvPwmMapperOutput *out)
{
  if (out == 0) {
    return;
  }

  out->rudder_us = 0U;
  out->elevator_us = 0U;
  out->thrust_us = 0U;
  out->publish = false;
  out->rudder_clamped = false;
  out->elevator_clamped = false;
  out->thrust_clamped = false;
}

void auv_pwm_mapper_map(const AuvPwmMapperConfig *cfg,
                        AuvSafetyState safety_state,
                        const AuvRuntimeLogicalCmd *cmd,
                        AuvPwmMapperOutput *out)
{
  if (out == 0) {
    return;
  }

  auv_pwm_mapper_zero(out);

  if (cfg == 0 || cmd == 0) {
    return;
  }

  if (safety_state != AUV_SAFETY_STATE_ARMED ||
      !auv_pwm_mapper_validate_config(cfg) ||
      !cmd->valid ||
      !command_finite(cmd)) {
    set_neutral_output(cfg, out);
    return;
  }

  map_channel(&cfg->rudder, cmd->delta_r, &out->rudder_us, &out->rudder_clamped);
  map_channel(&cfg->elevator, cmd->delta_e, &out->elevator_us, &out->elevator_clamped);
  map_channel(&cfg->thrust, cmd->thrust, &out->thrust_us, &out->thrust_clamped);
  out->publish = true;
}
