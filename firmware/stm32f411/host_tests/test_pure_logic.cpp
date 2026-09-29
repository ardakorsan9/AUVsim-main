#include "auv_pwm_mapper.h"
#include "auv_safety_fsm.h"
#include "auv_telemetry.h"
#include "auv_watchdog_policy.h"

#if defined(AUV_HOST_SANITIZERS_ENABLED)
#if !defined(__SANITIZE_ADDRESS__) || !defined(__SANITIZE_UNDEFINED__)
#error "Host sanitizers enabled but compiler did not activate ASan/UBSan"
#endif
#endif

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>

namespace {

int g_failures = 0;

void expect_true(bool condition, const char *label)
{
  if (!condition) {
    std::printf("FAIL: %s\n", label);
    ++g_failures;
  }
}

void expect_false(bool condition, const char *label)
{
  expect_true(!condition, label);
}

void expect_eq_u32(uint32_t actual, uint32_t expected, const char *label)
{
  if (actual != expected) {
    std::printf("FAIL: %s (got %u expected %u)\n", label, actual, expected);
    ++g_failures;
  }
}

void expect_eq_u16(uint16_t actual, uint16_t expected, const char *label)
{
  if (actual != expected) {
    std::printf("FAIL: %s (got %u expected %u)\n", label, actual, expected);
    ++g_failures;
  }
}

void expect_eq_size(size_t actual, size_t expected, const char *label)
{
  if (actual != expected) {
    std::printf("FAIL: %s (got %zu expected %zu)\n", label, actual, expected);
    ++g_failures;
  }
}

void expect_eq_state(AuvSafetyState actual, AuvSafetyState expected, const char *label)
{
  if (actual != expected) {
    std::printf("FAIL: %s (state %d expected %d)\n", label, static_cast<int>(actual),
                static_cast<int>(expected));
    ++g_failures;
  }
}

AuvSafetyInputs make_safe_inputs()
{
  AuvSafetyInputs inputs = {};
  inputs.arm_request = true;
  inputs.kill = false;
  inputs.scheduler_overrun = false;
  inputs.sample_valid = true;
  inputs.runtime_valid = true;
  inputs.config_valid = true;
  inputs.critical_fault = false;
  inputs.reset_from_kill = false;
  return inputs;
}

AuvSafetyInputs inputs_from_mask(uint8_t mask)
{
  AuvSafetyInputs inputs = {};
  inputs.arm_request = (mask & 0x01U) != 0U;
  inputs.kill = (mask & 0x02U) != 0U;
  inputs.scheduler_overrun = (mask & 0x04U) != 0U;
  inputs.sample_valid = (mask & 0x08U) != 0U;
  inputs.runtime_valid = (mask & 0x10U) != 0U;
  inputs.config_valid = (mask & 0x20U) != 0U;
  inputs.critical_fault = (mask & 0x40U) != 0U;
  inputs.reset_from_kill = (mask & 0x80U) != 0U;
  return inputs;
}

bool arm_prerequisites_met(const AuvSafetyInputs &inputs)
{
  return !inputs.kill &&
         !inputs.scheduler_overrun &&
         inputs.sample_valid &&
         inputs.runtime_valid &&
         inputs.config_valid;
}

AuvPwmChannelConfig make_channel(double neutral_us,
                                 double min_us,
                                 double max_us,
                                 double scale,
                                 double direction)
{
  AuvPwmChannelConfig channel = {};
  channel.neutral_us = neutral_us;
  channel.min_us = min_us;
  channel.max_us = max_us;
  channel.scale = scale;
  channel.direction = direction;
  return channel;
}

AuvPwmMapperConfig make_valid_pwm_config()
{
  AuvPwmMapperConfig cfg = {};
  cfg.rudder = make_channel(1500.0, 1100.0, 1900.0, 400.0, 1.0);
  cfg.elevator = make_channel(1500.0, 1100.0, 1900.0, 400.0, 1.0);
  cfg.thrust = make_channel(1500.0, 1000.0, 2000.0, 500.0, 1.0);
  return cfg;
}

AuvRuntimeLogicalCmd make_valid_cmd(double delta_r, double delta_e, double thrust)
{
  AuvRuntimeLogicalCmd cmd = {};
  cmd.delta_r = delta_r;
  cmd.delta_e = delta_e;
  cmd.thrust = thrust;
  cmd.valid = true;
  return cmd;
}

uint16_t crc16_ccitt(const uint8_t *data, size_t length)
{
  uint16_t crc = 0xFFFFU;
  const uint16_t poly = 0x1021U;

  for (size_t index = 0U; index < length; ++index) {
    crc ^= static_cast<uint16_t>(static_cast<uint16_t>(data[index]) << 8U);
    for (uint8_t bit = 0U; bit < 8U; ++bit) {
      if ((crc & 0x8000U) != 0U) {
        crc = static_cast<uint16_t>((crc << 1U) ^ poly);
      } else {
        crc = static_cast<uint16_t>(crc << 1U);
      }
    }
  }

  return crc;
}

AuvTelemetryStatusInput make_telemetry_input(uint32_t sequence)
{
  AuvTelemetryStatusInput input = {};
  input.sequence = sequence;
  input.safety_state = AUV_SAFETY_STATE_ARMED;
  input.sample_valid = true;
  input.runtime_valid = true;
  input.config_valid = true;
  input.critical_fault = false;
  input.pwm_publish = true;
  input.rudder_clamped = false;
  input.elevator_clamped = true;
  input.thrust_clamped = false;
  input.scheduler_overrun = false;
  input.mailbox_overrun = true;
  input.rudder_us = 1510U;
  input.elevator_us = 1620U;
  input.thrust_us = 1750U;
  return input;
}

void test_safety_fsm()
{
  AuvSafetyFsm fsm = {};
  AuvSafetyOutputs outputs = {};

  auv_safety_fsm_init(&fsm);
  expect_eq_state(fsm.state, AUV_SAFETY_STATE_DISARMED, "safety init disarmed");

  AuvSafetyInputs inputs = make_safe_inputs();
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  expect_eq_state(outputs.state, AUV_SAFETY_STATE_ARMED, "safety arm from disarmed");
  expect_true(outputs.publish_allowed, "safety publish allowed when armed");

  inputs.arm_request = false;
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  expect_eq_state(outputs.state, AUV_SAFETY_STATE_DISARMED, "safety disarm when arm request cleared");
  expect_false(outputs.publish_allowed, "safety publish blocked when disarmed");

  inputs = make_safe_inputs();
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  expect_eq_state(outputs.state, AUV_SAFETY_STATE_ARMED, "safety re-arm");

  inputs.kill = true;
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  expect_eq_state(outputs.state, AUV_SAFETY_STATE_KILLED, "safety kill latch");
  expect_false(outputs.publish_allowed, "safety publish blocked when killed");

  inputs.kill = false;
  inputs.arm_request = true;
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  expect_eq_state(outputs.state, AUV_SAFETY_STATE_KILLED, "safety kill remains latched");

  inputs.arm_request = false;
  inputs.reset_from_kill = true;
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  expect_eq_state(outputs.state, AUV_SAFETY_STATE_DISARMED, "safety reset from kill");

  auv_safety_fsm_init(&fsm);
  inputs = make_safe_inputs();
  inputs.critical_fault = true;
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  expect_eq_state(outputs.state, AUV_SAFETY_STATE_KILLED, "safety critical fault kills");

  auv_safety_fsm_init(&fsm);
  inputs = make_safe_inputs();
  inputs.sample_valid = false;
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  expect_eq_state(outputs.state, AUV_SAFETY_STATE_DISARMED, "safety stale sample blocks arm");

  auv_safety_fsm_init(&fsm);
  inputs = make_safe_inputs();
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  inputs.runtime_valid = false;
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  expect_eq_state(outputs.state, AUV_SAFETY_STATE_DISARMED, "safety stale runtime disarms");

  auv_safety_fsm_init(&fsm);
  inputs = make_safe_inputs();
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  inputs.config_valid = false;
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  expect_eq_state(outputs.state, AUV_SAFETY_STATE_DISARMED, "safety invalid config disarms");

  auv_safety_fsm_init(&fsm);
  inputs = make_safe_inputs();
  inputs.scheduler_overrun = true;
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  expect_eq_state(outputs.state, AUV_SAFETY_STATE_DISARMED, "safety scheduler overrun blocks arm");
}

void test_safety_fsm_property_boot_and_disarm_exhaustive()
{
  AuvSafetyFsm fsm = {};
  AuvSafetyOutputs outputs = {};

  auv_safety_fsm_init(&fsm);
  expect_eq_state(fsm.state, AUV_SAFETY_STATE_DISARMED, "property boot disarmed");

  for (uint16_t mask = 0U; mask < 256U; ++mask) {
    auv_safety_fsm_init(&fsm);
    const AuvSafetyInputs inputs = inputs_from_mask(static_cast<uint8_t>(mask));
    auv_safety_fsm_step(&fsm, &inputs, &outputs);

    if (inputs.kill || inputs.critical_fault) {
      expect_eq_state(outputs.state, AUV_SAFETY_STATE_KILLED, "property kill dominance from boot");
      expect_false(outputs.publish_allowed, "property kill blocks publish from boot");
      continue;
    }

    const bool may_arm = inputs.arm_request && arm_prerequisites_met(inputs);
    if (may_arm) {
      expect_eq_state(outputs.state, AUV_SAFETY_STATE_ARMED, "property exhaustive arm");
      expect_true(outputs.publish_allowed, "property exhaustive publish when armed");
    } else {
      expect_eq_state(outputs.state, AUV_SAFETY_STATE_DISARMED, "property exhaustive disarmed");
      expect_false(outputs.publish_allowed, "property exhaustive publish blocked");
    }
  }
}

void test_safety_fsm_property_kill_latch_and_reset()
{
  AuvSafetyFsm fsm = {};
  AuvSafetyOutputs outputs = {};
  AuvSafetyInputs inputs = make_safe_inputs();

  auv_safety_fsm_init(&fsm);
  inputs.kill = true;
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  expect_eq_state(outputs.state, AUV_SAFETY_STATE_KILLED, "property setup killed");

  for (uint16_t mask = 0U; mask < 256U; ++mask) {
    inputs = inputs_from_mask(static_cast<uint8_t>(mask));
    inputs.kill = false;
    inputs.critical_fault = false;
    inputs.reset_from_kill = false;
    auv_safety_fsm_step(&fsm, &inputs, &outputs);
    expect_eq_state(outputs.state, AUV_SAFETY_STATE_KILLED, "property kill latch holds");
    expect_false(outputs.publish_allowed, "property kill latch blocks publish");
  }

  for (uint8_t arm_bit = 0U; arm_bit < 2U; ++arm_bit) {
    auv_safety_fsm_init(&fsm);
    inputs = make_safe_inputs();
    inputs.kill = true;
    auv_safety_fsm_step(&fsm, &inputs, &outputs);

    inputs.kill = false;
    inputs.reset_from_kill = true;
    inputs.arm_request = (arm_bit != 0U);
    auv_safety_fsm_step(&fsm, &inputs, &outputs);

    if (inputs.arm_request) {
      expect_eq_state(outputs.state, AUV_SAFETY_STATE_KILLED, "property reset blocked while arm held");
      expect_false(outputs.publish_allowed, "property reset with arm does not publish");
    } else {
      expect_eq_state(outputs.state, AUV_SAFETY_STATE_DISARMED, "property reset to disarmed");
      expect_false(outputs.publish_allowed, "property reset cannot auto-arm");
    }
  }

  auv_safety_fsm_init(&fsm);
  inputs = make_safe_inputs();
  inputs.kill = true;
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  inputs.kill = false;
  inputs.arm_request = false;
  inputs.reset_from_kill = true;
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  expect_eq_state(outputs.state, AUV_SAFETY_STATE_DISARMED, "property reset sequence disarmed");

  inputs = make_safe_inputs();
  auv_safety_fsm_step(&fsm, &inputs, &outputs);
  expect_eq_state(outputs.state, AUV_SAFETY_STATE_ARMED, "property explicit re-arm after reset");
}

void test_safety_fsm_property_stale_invalid_fail_closed()
{
  AuvSafetyFsm fsm = {};
  AuvSafetyOutputs outputs = {};

  const bool validity_flags[] = {false, true};
  for (size_t sample_index = 0U; sample_index < 2U; ++sample_index) {
    for (size_t runtime_index = 0U; runtime_index < 2U; ++runtime_index) {
      for (size_t config_index = 0U; config_index < 2U; ++config_index) {
        for (size_t overrun_index = 0U; overrun_index < 2U; ++overrun_index) {
          auv_safety_fsm_init(&fsm);
          AuvSafetyInputs inputs = make_safe_inputs();
          inputs.sample_valid = validity_flags[sample_index];
          inputs.runtime_valid = validity_flags[runtime_index];
          inputs.config_valid = validity_flags[config_index];
          inputs.scheduler_overrun = validity_flags[overrun_index];
          auv_safety_fsm_step(&fsm, &inputs, &outputs);
          if (arm_prerequisites_met(inputs) && inputs.arm_request) {
            expect_eq_state(outputs.state, AUV_SAFETY_STATE_ARMED,
                            "property valid inputs may arm from boot");
          } else {
            expect_eq_state(outputs.state, AUV_SAFETY_STATE_DISARMED,
                            "property stale invalid fail-closed from boot");
          }

          auv_safety_fsm_init(&fsm);
          inputs = make_safe_inputs();
          auv_safety_fsm_step(&fsm, &inputs, &outputs);
          expect_eq_state(outputs.state, AUV_SAFETY_STATE_ARMED, "property armed setup");

          inputs.sample_valid = validity_flags[sample_index];
          inputs.runtime_valid = validity_flags[runtime_index];
          inputs.config_valid = validity_flags[config_index];
          inputs.scheduler_overrun = validity_flags[overrun_index];
          auv_safety_fsm_step(&fsm, &inputs, &outputs);

          const bool prerequisites = arm_prerequisites_met(inputs);
          if (prerequisites && inputs.arm_request) {
            expect_eq_state(outputs.state, AUV_SAFETY_STATE_ARMED, "property armed remains when valid");
          } else {
            expect_eq_state(outputs.state, AUV_SAFETY_STATE_DISARMED,
                            "property armed disarms on stale invalid input");
            expect_false(outputs.publish_allowed, "property stale invalid blocks publish");
          }
        }
      }
    }
  }
}

void test_pwm_mapper()
{
  const AuvPwmMapperConfig cfg = make_valid_pwm_config();
  expect_true(auv_pwm_mapper_validate_config(&cfg), "pwm valid config accepted");

  AuvPwmMapperConfig bad_cfg = cfg;
  bad_cfg.rudder.min_us = 1600.0;
  expect_false(auv_pwm_mapper_validate_config(&bad_cfg), "pwm invalid config rejected");

  AuvPwmMapperOutput out = {};
  AuvRuntimeLogicalCmd cmd = make_valid_cmd(0.0, 0.0, 0.0);

  auv_pwm_mapper_map(&cfg, AUV_SAFETY_STATE_DISARMED, &cmd, &out);
  expect_false(out.publish, "pwm disarmed yields neutral without publish");
  expect_eq_u16(out.rudder_us, 1500U, "pwm disarmed rudder neutral");
  expect_eq_u16(out.elevator_us, 1500U, "pwm disarmed elevator neutral");
  expect_eq_u16(out.thrust_us, 1500U, "pwm disarmed thrust neutral");

  cmd = make_valid_cmd(1.25, -0.5, 0.25);
  auv_pwm_mapper_map(&cfg, AUV_SAFETY_STATE_ARMED, &cmd, &out);
  expect_true(out.publish, "pwm armed valid command publishes");
  expect_eq_u16(out.rudder_us, 1900U, "pwm rudder clamp high");
  expect_true(out.rudder_clamped, "pwm rudder clamp flag set");
  expect_eq_u16(out.elevator_us, 1300U, "pwm elevator mapped");
  expect_false(out.elevator_clamped, "pwm elevator not clamped");
  expect_eq_u16(out.thrust_us, 1625U, "pwm thrust mapped");

  cmd.valid = false;
  auv_pwm_mapper_map(&cfg, AUV_SAFETY_STATE_ARMED, &cmd, &out);
  expect_false(out.publish, "pwm invalid command fail-closed");
  expect_eq_u16(out.rudder_us, 1500U, "pwm invalid command rudder neutral");

  cmd = make_valid_cmd(0.0, 0.0, 0.0);
  cmd.thrust = INFINITY;
  auv_pwm_mapper_map(&cfg, AUV_SAFETY_STATE_ARMED, &cmd, &out);
  expect_false(out.publish, "pwm non-finite command fail-closed");

  auv_pwm_mapper_map(&bad_cfg, AUV_SAFETY_STATE_ARMED, &cmd, &out);
  expect_false(out.publish, "pwm rejected config fail-closed");
}

bool pwm_within_channel_bounds(uint16_t pwm_us, const AuvPwmChannelConfig &channel)
{
  const uint16_t min_us = static_cast<uint16_t>(channel.min_us + 0.5);
  const uint16_t max_us = static_cast<uint16_t>(channel.max_us + 0.5);
  return pwm_us >= min_us && pwm_us <= max_us;
}

void test_pwm_mapper_property_bounds_and_fail_closed()
{
  const AuvPwmMapperConfig cfg = make_valid_pwm_config();
  const double samples[] = {-10.0, -2.0, -1.25, -0.5, 0.0, 0.25, 0.5, 1.0, 1.25, 2.0, 10.0};
  const AuvSafetyState safety_states[] = {
      AUV_SAFETY_STATE_DISARMED,
      AUV_SAFETY_STATE_ARMED,
      AUV_SAFETY_STATE_KILLED,
  };

  for (size_t state_index = 0U; state_index < 3U; ++state_index) {
  for (size_t r_index = 0U; r_index < sizeof(samples) / sizeof(samples[0]); ++r_index) {
  for (size_t e_index = 0U; e_index < sizeof(samples) / sizeof(samples[0]); ++e_index) {
  for (size_t t_index = 0U; t_index < sizeof(samples) / sizeof(samples[0]); ++t_index) {
    AuvRuntimeLogicalCmd cmd = make_valid_cmd(samples[r_index], samples[e_index], samples[t_index]);
    AuvPwmMapperOutput out = {};
    auv_pwm_mapper_map(&cfg, safety_states[state_index], &cmd, &out);

    expect_true(out.rudder_us >= AUV_PWM_MAPPER_ABS_MIN_US, "property pwm rudder abs min");
    expect_true(out.rudder_us <= AUV_PWM_MAPPER_ABS_MAX_US, "property pwm rudder abs max");
    expect_true(out.elevator_us >= AUV_PWM_MAPPER_ABS_MIN_US, "property pwm elevator abs min");
    expect_true(out.elevator_us <= AUV_PWM_MAPPER_ABS_MAX_US, "property pwm elevator abs max");
    expect_true(out.thrust_us >= AUV_PWM_MAPPER_ABS_MIN_US, "property pwm thrust abs min");
    expect_true(out.thrust_us <= AUV_PWM_MAPPER_ABS_MAX_US, "property pwm thrust abs max");

    if (safety_states[state_index] != AUV_SAFETY_STATE_ARMED) {
      expect_false(out.publish, "property pwm non-armed fail-closed");
      expect_eq_u16(out.rudder_us, 1500U, "property pwm non-armed rudder neutral");
      expect_eq_u16(out.elevator_us, 1500U, "property pwm non-armed elevator neutral");
      expect_eq_u16(out.thrust_us, 1500U, "property pwm non-armed thrust neutral");
      continue;
    }

    expect_true(out.publish, "property pwm armed valid publishes");
    expect_true(pwm_within_channel_bounds(out.rudder_us, cfg.rudder), "property pwm rudder channel bounds");
    expect_true(pwm_within_channel_bounds(out.elevator_us, cfg.elevator),
                "property pwm elevator channel bounds");
    expect_true(pwm_within_channel_bounds(out.thrust_us, cfg.thrust), "property pwm thrust channel bounds");
  }}}}

  const double non_finite_values[] = {INFINITY, -INFINITY, NAN};
  for (size_t nf_index = 0U; nf_index < 3U; ++nf_index) {
    for (uint8_t axis = 0U; axis < 3U; ++axis) {
      AuvRuntimeLogicalCmd cmd = make_valid_cmd(0.0, 0.0, 0.0);
      if (axis == 0U) {
        cmd.delta_r = non_finite_values[nf_index];
      } else if (axis == 1U) {
        cmd.delta_e = non_finite_values[nf_index];
      } else {
        cmd.thrust = non_finite_values[nf_index];
      }

      AuvPwmMapperOutput out = {};
      auv_pwm_mapper_map(&cfg, AUV_SAFETY_STATE_ARMED, &cmd, &out);
      expect_false(out.publish, "property pwm non-finite fail-closed");
      expect_eq_u16(out.rudder_us, 1500U, "property pwm non-finite rudder neutral");
      expect_eq_u16(out.elevator_us, 1500U, "property pwm non-finite elevator neutral");
      expect_eq_u16(out.thrust_us, 1500U, "property pwm non-finite thrust neutral");
    }
  }

  for (uint8_t valid_bit = 0U; valid_bit < 2U; ++valid_bit) {
    AuvRuntimeLogicalCmd cmd = make_valid_cmd(1.0, -1.0, 0.5);
    cmd.valid = (valid_bit != 0U);
    AuvPwmMapperOutput out = {};
    auv_pwm_mapper_map(&cfg, AUV_SAFETY_STATE_ARMED, &cmd, &out);
    if (!cmd.valid) {
      expect_false(out.publish, "property pwm invalid cmd fail-closed");
      expect_eq_u16(out.rudder_us, 1500U, "property pwm invalid cmd rudder neutral");
    } else {
      expect_true(out.publish, "property pwm valid cmd publishes");
    }
  }
}

void test_telemetry()
{
  uint8_t frame[AUV_TELEMETRY_STATUS_FRAME_BYTES] = {};
  const AuvTelemetryStatusInput input = make_telemetry_input(42U);

  expect_eq_size(auv_telemetry_encode_status(&input, frame, sizeof(frame)),
                 static_cast<size_t>(AUV_TELEMETRY_STATUS_FRAME_BYTES),
                 "telemetry exact frame length");

  expect_eq_u32(frame[0], AUV_TELEMETRY_SYNC_BYTE0, "telemetry sync0");
  expect_eq_u32(frame[1], AUV_TELEMETRY_SYNC_BYTE1, "telemetry sync1");
  expect_eq_u32(frame[2], AUV_TELEMETRY_VERSION, "telemetry version");
  expect_eq_u32(frame[3], static_cast<uint8_t>(AUV_TELEMETRY_STATUS_PAYLOAD_LENGTH & 0xFFU),
                "telemetry payload length lo");
  expect_eq_u32(frame[4], static_cast<uint8_t>((AUV_TELEMETRY_STATUS_PAYLOAD_LENGTH >> 8U) & 0xFFU),
                "telemetry payload length hi");

  const uint16_t expected_crc =
      crc16_ccitt(frame, static_cast<size_t>(AUV_TELEMETRY_STATUS_FRAME_BYTES) - 2U);
  const uint16_t frame_crc =
      static_cast<uint16_t>(frame[18U] | (static_cast<uint16_t>(frame[19U]) << 8U));
  expect_eq_u16(frame_crc, expected_crc, "telemetry crc matches payload");

  uint8_t small_buffer[8] = {};
  expect_eq_size(auv_telemetry_encode_status(&input, small_buffer, sizeof(small_buffer)), 0U,
                 "telemetry small buffer rejected");

  AuvTelemetryStatusInput changed = input;
  changed.sequence = 43U;
  uint8_t changed_frame[AUV_TELEMETRY_STATUS_FRAME_BYTES] = {};
  expect_eq_size(auv_telemetry_encode_status(&changed, changed_frame, sizeof(changed_frame)),
                 static_cast<size_t>(AUV_TELEMETRY_STATUS_FRAME_BYTES),
                 "telemetry changed frame length");
  expect_true(std::memcmp(frame, changed_frame, sizeof(frame)) != 0,
              "telemetry change detection");

  const uint8_t expected_health =
      static_cast<uint8_t>(AUV_TELEM_HEALTH_SAMPLE_VALID | AUV_TELEM_HEALTH_RUNTIME_VALID |
                           AUV_TELEM_HEALTH_CONFIG_VALID | AUV_TELEM_HEALTH_PWM_PUBLISH |
                           AUV_TELEM_HEALTH_ELEVATOR_CLAMPED);
  expect_eq_u32(frame[10], expected_health, "telemetry health bits packed");
  expect_eq_u32(frame[11], AUV_TELEM_TICK_MAILBOX_OVERRUN, "telemetry tick overrun packed");
}

void test_watchdog_policy()
{
  const AuvWatchdogPolicyLimits limits = {5U, 20U};
  expect_true(auv_watchdog_policy_limits_valid(&limits), "watchdog limits valid");

  AuvWatchdogPolicyLimits bad_limits = {25U, 20U};
  expect_false(auv_watchdog_policy_limits_valid(&bad_limits), "watchdog limits invalid");

  AuvWatchdogPolicyInputs inputs = {};
  AuvWatchdogPolicyOutputs outputs = {};

  inputs.scheduler_progressed = true;
  inputs.scheduler_overrun = false;
  inputs.kill = false;
  inputs.critical_fault = false;
  inputs.safety_state = AUV_SAFETY_STATE_ARMED;
  inputs.safety_state_valid = true;
  inputs.observed_tick_age = 10U;
  inputs.tick_observation_valid = true;

  auv_watchdog_policy_decide(&limits, &inputs, &outputs);
  expect_true(outputs.may_feed, "watchdog feed allowed when healthy");

  inputs.scheduler_progressed = false;
  auv_watchdog_policy_decide(&limits, &inputs, &outputs);
  expect_false(outputs.may_feed, "watchdog deny no scheduler progress");

  inputs.scheduler_progressed = true;
  inputs.scheduler_overrun = true;
  auv_watchdog_policy_decide(&limits, &inputs, &outputs);
  expect_false(outputs.may_feed, "watchdog deny scheduler overrun");

  inputs.scheduler_overrun = false;
  inputs.kill = true;
  auv_watchdog_policy_decide(&limits, &inputs, &outputs);
  expect_false(outputs.may_feed, "watchdog deny kill");

  inputs.kill = false;
  inputs.critical_fault = true;
  auv_watchdog_policy_decide(&limits, &inputs, &outputs);
  expect_false(outputs.may_feed, "watchdog deny critical fault");

  inputs.critical_fault = false;
  inputs.safety_state = AUV_SAFETY_STATE_DISARMED;
  auv_watchdog_policy_decide(&limits, &inputs, &outputs);
  expect_false(outputs.may_feed, "watchdog deny disarmed");

  inputs.safety_state = AUV_SAFETY_STATE_ARMED;
  inputs.safety_state_valid = false;
  auv_watchdog_policy_decide(&limits, &inputs, &outputs);
  expect_false(outputs.may_feed, "watchdog deny invalid safety state flag");

  inputs.safety_state_valid = true;
  inputs.tick_observation_valid = false;
  auv_watchdog_policy_decide(&limits, &inputs, &outputs);
  expect_false(outputs.may_feed, "watchdog deny missing tick observation");

  inputs.tick_observation_valid = true;
  inputs.observed_tick_age = 4U;
  auv_watchdog_policy_decide(&limits, &inputs, &outputs);
  expect_false(outputs.may_feed, "watchdog deny tick too young");

  inputs.observed_tick_age = 21U;
  auv_watchdog_policy_decide(&limits, &inputs, &outputs);
  expect_false(outputs.may_feed, "watchdog deny tick too old");

  auv_watchdog_policy_decide(&bad_limits, &inputs, &outputs);
  expect_false(outputs.may_feed, "watchdog deny invalid limits");
}

AuvWatchdogPolicyInputs healthy_watchdog_inputs()
{
  AuvWatchdogPolicyInputs inputs = {};
  inputs.scheduler_progressed = true;
  inputs.scheduler_overrun = false;
  inputs.kill = false;
  inputs.critical_fault = false;
  inputs.safety_state = AUV_SAFETY_STATE_ARMED;
  inputs.safety_state_valid = true;
  inputs.observed_tick_age = 10U;
  inputs.tick_observation_valid = true;
  return inputs;
}

void test_watchdog_policy_property_feed_denial_exhaustive()
{
  const AuvWatchdogPolicyLimits limits = {5U, 20U};
  AuvWatchdogPolicyOutputs outputs = {};

  for (uint16_t mask = 0U; mask < 256U; ++mask) {
    AuvWatchdogPolicyInputs inputs = healthy_watchdog_inputs();
    inputs.scheduler_progressed = (mask & 0x01U) != 0U;
    inputs.scheduler_overrun = (mask & 0x02U) != 0U;
    inputs.kill = (mask & 0x04U) != 0U;
    inputs.critical_fault = (mask & 0x08U) != 0U;
    inputs.safety_state_valid = (mask & 0x10U) != 0U;
    inputs.tick_observation_valid = (mask & 0x20U) != 0U;
    const uint8_t state_selector = static_cast<uint8_t>((mask >> 6U) & 0x03U);
    if (state_selector == 0U) {
      inputs.safety_state = AUV_SAFETY_STATE_DISARMED;
    } else if (state_selector == 1U) {
      inputs.safety_state = AUV_SAFETY_STATE_ARMED;
    } else {
      inputs.safety_state = AUV_SAFETY_STATE_KILLED;
    }

    auv_watchdog_policy_decide(&limits, &inputs, &outputs);

    const bool feed_allowed =
        inputs.scheduler_progressed &&
        !inputs.scheduler_overrun &&
        !inputs.kill &&
        !inputs.critical_fault &&
        inputs.safety_state_valid &&
        inputs.tick_observation_valid &&
        inputs.safety_state == AUV_SAFETY_STATE_ARMED &&
        inputs.observed_tick_age >= limits.min_tick_age &&
        inputs.observed_tick_age <= limits.max_tick_age;

    if (feed_allowed) {
      expect_true(outputs.may_feed, "property watchdog feed allowed");
    } else {
      expect_false(outputs.may_feed, "property watchdog feed denied");
    }
  }

  const uint32_t tick_ages[] = {0U, 4U, 5U, 10U, 20U, 21U, 100U};
  for (size_t age_index = 0U; age_index < sizeof(tick_ages) / sizeof(tick_ages[0]); ++age_index) {
    AuvWatchdogPolicyInputs inputs = healthy_watchdog_inputs();
    inputs.observed_tick_age = tick_ages[age_index];
    auv_watchdog_policy_decide(&limits, &inputs, &outputs);

    const bool in_window =
        inputs.observed_tick_age >= limits.min_tick_age &&
        inputs.observed_tick_age <= limits.max_tick_age;
    if (in_window) {
      expect_true(outputs.may_feed, "property watchdog tick age in window");
    } else {
      expect_false(outputs.may_feed, "property watchdog tick age out of window");
    }
  }
}

}  // namespace

int main()
{
  test_safety_fsm();
  test_safety_fsm_property_boot_and_disarm_exhaustive();
  test_safety_fsm_property_kill_latch_and_reset();
  test_safety_fsm_property_stale_invalid_fail_closed();
  test_pwm_mapper();
  test_pwm_mapper_property_bounds_and_fail_closed();
  test_telemetry();
  test_watchdog_policy();
  test_watchdog_policy_property_feed_denial_exhaustive();

  if (g_failures != 0) {
    std::printf("%d test assertion(s) failed\n", g_failures);
    return 1;
  }

  std::printf("all pure logic tests passed\n");
  return 0;
}
