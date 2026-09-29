/*
 * HAL-free native host integration test: runtime port -> adapter -> safety FSM
 * -> PWM mapper -> telemetry -> watchdog over fixed 25 ms sample sequences.
 * PRETARGET / NOT_IN_PRODUCTION / NOT_CERTIFIED
 */

#include "auv_pwm_mapper.h"
#include "auv_runtime_adapter.h"
#include "auv_runtime_port.h"
#include "auv_safety_fsm.h"
#include "auv_telemetry.h"
#include "auv_watchdog_policy.h"

#include <cmath>
#include <cstdio>
#include <cstring>

#if AUV_SCHEDULER_PERIOD_MS != 25
#error "host e2e chain requires AUV_SCHEDULER_PERIOD_MS=25"
#endif

namespace {

constexpr double kDtSec = static_cast<double>(AUV_SCHEDULER_PERIOD_MS) / 1000.0;
constexpr size_t kSampleCount = 16U;

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

void expect_eq_state(AuvSafetyState actual, AuvSafetyState expected, const char *label)
{
  if (actual != expected) {
    std::printf("FAIL: %s (state %d expected %d)\n", label, static_cast<int>(actual),
                static_cast<int>(expected));
    ++g_failures;
  }
}

void expect_eq_u32(uint32_t actual, uint32_t expected, const char *label)
{
  if (actual != expected) {
    std::printf("FAIL: %s (got %u expected %u)\n", label, actual, expected);
    ++g_failures;
  }
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

struct SampleFlags {
  bool arm_request;
  bool kill;
  bool scheduler_overrun;
  bool sample_valid;
  bool reset_from_kill;
  bool call_port_reset;
};

static const SampleFlags kSequence[kSampleCount] = {
    {false, false, false, true, false, false},
    {false, false, false, true, false, false},
    {false, false, false, true, false, false},
    {false, false, false, true, false, false},
    {true, false, false, true, false, false},
    {true, false, false, true, false, false},
    {true, false, false, true, false, false},
    {true, false, false, true, false, false},
    {true, false, false, true, false, false},
    {true, false, false, true, false, false},
    {true, true, false, true, false, false},
    {false, false, false, true, false, false},
    {false, false, false, true, true, false},
    {false, false, false, true, false, true},
    {false, false, false, true, false, false},
    {true, false, false, true, false, false},
};

AuvRuntimeConfig make_valid_config()
{
  AuvRuntimeConfig cfg = {};

  cfg.controller.Kp_psi = 1.0;
  cfg.controller.Kd_psi = 0.5;
  cfg.controller.Kp_x = 0.5;
  cfg.controller.Kp_roll = 0.5;
  cfg.controller.Kp_angle = 2.0;
  cfg.controller.Ki_angle = 0.1;
  cfg.controller.Kp_rate = 1.0;
  cfg.controller.Ki_rate = 0.05;
  cfg.controller.Kaw_pitch = 0.1;
  cfg.controller.Kd_rate = 0.2;
  cfg.controller.Kd_damp = 0.1;
  cfg.controller.delta_r_max = 0.5;
  cfg.controller.delta_e_max = 0.5;
  cfg.controller.thrust_max = 100.0;
  cfg.controller.thrust_min = 0.0;
  cfg.controller.thrust_trim = 50.0;
  cfg.controller.trim_speed_table[0] = 0.0;
  cfg.controller.trim_speed_table[1] = 0.5;
  cfg.controller.trim_speed_table[2] = 1.0;
  cfg.controller.trim_speed_table[3] = 2.0;
  cfg.controller.trim_elevator_table[0] = 0.0;
  cfg.controller.trim_elevator_table[1] = 0.0;
  cfg.controller.trim_elevator_table[2] = 0.0;
  cfg.controller.trim_elevator_table[3] = 0.0;
  cfg.controller.elevator_sign = -1.0;
  cfg.controller.dt_controller = kDtSec;
  cfg.controller.tau_rate = 0.1;
  cfg.controller.Muw = 1.0;
  cfg.controller.Muuds = 1.0;
  cfg.controller.lambda_muw_ff = 0.5;
  cfg.controller.muw_ff_u_min = 0.1;
  cfg.controller.muw_ff_u_lo = 0.5;
  cfg.controller.muw_ff_u_hi = 2.0;
  cfg.controller.muw_ff_clamp_deg = 5.0;
  cfg.controller.delta_e_trim = 0.0;
  cfg.controller.k_gamma_climb = 0.5;
  cfg.controller.de_climb_lim = 0.3;
  cfg.controller.slew_max_rad_s = 1.0;

  cfg.guidance.MAX_PATH_POINTS = 32.0;
  cfg.guidance.lookahead_distance = 5.0;
  cfg.guidance.desired_speed = 1.0;
  cfg.guidance.pitch_ref_max = 0.5;
  cfg.guidance.pitch_ref_rate_max = 0.5;
  cfg.guidance.dt_guidance = 3.0 * kDtSec;
  cfg.guidance.dt_controller = kDtSec;
  cfg.guidance.yaw_slew_max_rad_s = 1.0;
  cfg.guidance.r_ff_max_rad_s = 1.0;

  for (int channel = 0; channel < 7; ++channel) {
    cfg.availability.present[channel] = true;
    cfg.availability.period[channel] = 0.1;
    cfg.availability.stale_limit[channel] = 0.5;
  }

  cfg.fdir.G_nom = 1.0;
  cfg.fdir.thr_B2 = 0.1;
  cfg.fdir.eps_dr_rad = 0.01;
  cfg.fdir.u_floor = 0.1;
  cfg.fdir.t_warmup_s = 1.0;
  cfg.fdir.Np = 5.0;
  cfg.fdir.persist_s = 0.5;
  cfg.fdir.dt = kDtSec;

  cfg.safe_thrust = 50.0;

  return cfg;
}

AuvPwmMapperConfig make_valid_pwm_config()
{
  AuvPwmMapperConfig cfg = {};
  cfg.rudder.neutral_us = 1500.0;
  cfg.rudder.min_us = 1100.0;
  cfg.rudder.max_us = 1900.0;
  cfg.rudder.scale = 400.0;
  cfg.rudder.direction = 1.0;
  cfg.elevator = cfg.rudder;
  cfg.thrust.neutral_us = 1500.0;
  cfg.thrust.min_us = 1000.0;
  cfg.thrust.max_us = 2000.0;
  cfg.thrust.scale = 500.0;
  cfg.thrust.direction = 1.0;
  return cfg;
}

void fill_path(AuvRuntimeIn *in)
{
  in->n_path = 2.0;
  for (size_t index = 0U; index < 96U; ++index) {
    in->path_pad[index] = static_cast<double>(index % 4U);
  }
}

void fill_nav_init(AuvRuntimeIn *in, unsigned int tick_seq)
{
  in->nav.op = 1U;
  in->nav.sample_valid = true;
  in->nav.init_gyro[0] = 0.0;
  in->nav.init_gyro[1] = 0.0;
  in->nav.init_gyro[2] = 0.0;
  in->nav.init_accel[0] = 0.0;
  in->nav.init_accel[1] = 0.0;
  in->nav.init_accel[2] = 9.81;
  in->nav.init_depth = 10.0;
  in->nav.init_heading = 0.0;
  in->nav.init_ins_vel[0] = 1.0;
  in->nav.init_ins_vel[1] = 0.0;
  in->nav.init_ins_vel[2] = 0.0;
  for (int index = 0; index < 5; ++index) {
    in->nav.init_timestamp[index] = in->t;
    in->nav.init_seq[index] = static_cast<double>(tick_seq + static_cast<unsigned int>(index) + 1U);
  }
}

void fill_nav_propagate(AuvRuntimeIn *in, unsigned int tick_seq)
{
  in->nav.op = 2U;
  in->nav.sample_valid = true;
  in->nav.gyro[0] = 0.0;
  in->nav.gyro[1] = 0.0;
  in->nav.gyro[2] = 0.0;
  in->nav.accel[0] = 0.0;
  in->nav.accel[1] = 0.0;
  in->nav.accel[2] = 9.81;
  in->nav.gyro_timestamp = in->t;
  in->nav.accel_timestamp = in->t;
  in->nav.gyro_seq = tick_seq;
  in->nav.accel_seq = tick_seq;
}

void fill_runtime_input(AuvRuntimeIn *in,
                        unsigned int tick_seq,
                        double t,
                        const SampleFlags &flags)
{
  std::memset(in, 0, sizeof(*in));
  in->t = t;
  in->tick_seq = tick_seq;
  in->sample_valid = flags.sample_valid;
  in->arm_request = flags.arm_request;
  in->kill_asserted = flags.kill;
  in->body_rates[0] = 0.0;
  in->body_rates[1] = 0.0;
  in->body_rates[2] = 0.0;
  in->nav.t = t;
  for (int channel = 0; channel < 7; ++channel) {
    in->accepted[channel] = true;
  }
  fill_path(in);
  if (tick_seq == 1U) {
    fill_nav_init(in, tick_seq);
  } else {
    fill_nav_propagate(in, tick_seq);
  }
}

bool write_pass_artifact(size_t sample_count)
{
  const char *path = AUV_PROJECT_ROOT "/artifacts/integration/trust_v3_host_e2e_pass.json";
  FILE *file = std::fopen(path, "wb");
  if (file == 0) {
    std::printf("FAIL: could not open pass artifact %s\n", path);
    return false;
  }

  std::fprintf(file,
               "{\n"
               "  \"pass\": true,\n"
               "  \"sample_count\": %zu,\n"
               "  \"tick_ms\": %d,\n"
               "  \"modules_linked\": [\n"
               "    \"auv_runtime_port\",\n"
               "    \"auv_runtime_adapter\",\n"
               "    \"auv_runtime_codegen_init\",\n"
               "    \"auv_safety_fsm\",\n"
               "    \"auv_pwm_mapper\",\n"
               "    \"auv_telemetry\",\n"
               "    \"auv_watchdog_policy\"\n"
               "  ]\n"
               "}\n",
               sample_count,
               AUV_SCHEDULER_PERIOD_MS);
  std::fclose(file);
  return true;
}

void run_e2e_chain()
{
  const AuvRuntimeConfig config = make_valid_config();
  const AuvPwmMapperConfig pwm_cfg = make_valid_pwm_config();
  const AuvWatchdogPolicyLimits watchdog_limits = {5U, 20U};

  AuvSafetyFsm safety_fsm = {};
  AuvSafetyOutputs safety_out = {};
  auv_safety_fsm_init(&safety_fsm);

  auv_runtime_port_initialize(&config);
  auv_runtime_port_reset();

  uint32_t telemetry_sequence = 0U;
  uint32_t observed_tick_age = 0U;

  for (size_t step = 0U; step < kSampleCount; ++step) {
    const SampleFlags &flags = kSequence[step];
    const unsigned int tick_seq = static_cast<unsigned int>(step) + 1U;
    const double t = static_cast<double>(step) * kDtSec;

    if (flags.call_port_reset) {
      auv_runtime_port_reset();
      auv_safety_fsm_init(&safety_fsm);
      observed_tick_age = 0U;
    }

    AuvRuntimeIn runtime_in = {};
    fill_runtime_input(&runtime_in, tick_seq, t, flags);

    AuvRuntimeOut runtime_out = {};
    const bool runtime_step_ok = auv_runtime_port_step(&runtime_in, &runtime_out);

    AuvRuntimeLogicalCmd logical_cmd = {};
    const bool adapter_ok = auv_runtime_adapter_update(&runtime_out, &logical_cmd);
    if (runtime_step_ok) {
      expect_true(adapter_ok, "adapter accepts published runtime output");
      expect_true(logical_cmd.valid, "logical command valid when runtime publishes");
    } else {
      expect_false(adapter_ok, "adapter fail-closed when runtime denies publish");
      expect_false(logical_cmd.valid, "logical command invalid when runtime denies publish");
    }

    AuvSafetyInputs safety_in = {};
    safety_in.arm_request = flags.arm_request;
    safety_in.kill = flags.kill;
    safety_in.scheduler_overrun = flags.scheduler_overrun;
    safety_in.sample_valid = flags.sample_valid;
    safety_in.runtime_valid = runtime_step_ok;
    safety_in.config_valid = true;
    safety_in.critical_fault = false;
    safety_in.reset_from_kill = flags.reset_from_kill;
    auv_safety_fsm_step(&safety_fsm, &safety_in, &safety_out);

    AuvPwmMapperOutput pwm_out = {};
    auv_pwm_mapper_map(&pwm_cfg, safety_out.state, &logical_cmd, &pwm_out);

    if (safety_out.state != AUV_SAFETY_STATE_ARMED || !logical_cmd.valid) {
      expect_false(pwm_out.publish, "pwm fail-closed unless armed with valid command");
      expect_eq_u32(pwm_out.rudder_us, 1500U, "pwm neutral rudder when fail-closed");
      expect_eq_u32(pwm_out.elevator_us, 1500U, "pwm neutral elevator when fail-closed");
      expect_eq_u32(pwm_out.thrust_us, 1500U, "pwm neutral thrust when fail-closed");
    } else {
      expect_true(pwm_out.publish, "pwm publishes when armed with valid command");
    }

    AuvTelemetryStatusInput telem_in = {};
    telem_in.sequence = telemetry_sequence;
    telem_in.safety_state = safety_out.state;
    telem_in.sample_valid = flags.sample_valid;
    telem_in.runtime_valid = runtime_step_ok;
    telem_in.config_valid = true;
    telem_in.critical_fault = false;
    telem_in.pwm_publish = pwm_out.publish;
    telem_in.rudder_clamped = pwm_out.rudder_clamped;
    telem_in.elevator_clamped = pwm_out.elevator_clamped;
    telem_in.thrust_clamped = pwm_out.thrust_clamped;
    telem_in.scheduler_overrun = flags.scheduler_overrun;
    telem_in.mailbox_overrun = false;
    telem_in.rudder_us = pwm_out.rudder_us;
    telem_in.elevator_us = pwm_out.elevator_us;
    telem_in.thrust_us = pwm_out.thrust_us;

    uint8_t frame[AUV_TELEMETRY_STATUS_FRAME_BYTES] = {};
    const size_t encoded =
        auv_telemetry_encode_status(&telem_in, frame, sizeof(frame));
    expect_eq_u32(static_cast<uint32_t>(encoded),
                  static_cast<uint32_t>(AUV_TELEMETRY_STATUS_FRAME_BYTES),
                  "telemetry frame length");
    const uint16_t expected_crc =
        crc16_ccitt(frame, static_cast<size_t>(AUV_TELEMETRY_STATUS_FRAME_BYTES) - 2U);
    const uint16_t frame_crc =
        static_cast<uint16_t>(frame[18U] | (static_cast<uint16_t>(frame[19U]) << 8U));
    expect_eq_u32(frame_crc, expected_crc, "telemetry crc");

    if (observed_tick_age < 100U) {
      ++observed_tick_age;
    }

    AuvWatchdogPolicyInputs watchdog_in = {};
    watchdog_in.scheduler_progressed = true;
    watchdog_in.scheduler_overrun = flags.scheduler_overrun;
    watchdog_in.kill = flags.kill;
    watchdog_in.critical_fault = false;
    watchdog_in.safety_state = safety_out.state;
    watchdog_in.safety_state_valid = true;
    watchdog_in.observed_tick_age = observed_tick_age;
    watchdog_in.tick_observation_valid = true;

    AuvWatchdogPolicyOutputs watchdog_out = {};
    auv_watchdog_policy_decide(&watchdog_limits, &watchdog_in, &watchdog_out);

    if (flags.kill) {
      expect_eq_state(safety_out.state, AUV_SAFETY_STATE_KILLED, "kill forces safety killed");
      expect_false(watchdog_out.may_feed, "watchdog denies feed on kill");
    }

    if (step < 4U) {
      expect_eq_state(safety_out.state, AUV_SAFETY_STATE_DISARMED, "boot phase disarmed");
      expect_false(watchdog_out.may_feed, "watchdog denies feed while disarmed");
    }

    if (step == 10U) {
      expect_eq_state(safety_out.state, AUV_SAFETY_STATE_KILLED, "kill sample latched");
    }

    if (step == 12U) {
      expect_eq_state(safety_out.state, AUV_SAFETY_STATE_DISARMED, "reset from kill returns disarmed");
    }

    if (step >= 5U && step <= 9U && safety_out.state == AUV_SAFETY_STATE_ARMED &&
        !flags.scheduler_overrun && !flags.kill) {
      expect_true(watchdog_out.may_feed, "watchdog feed allowed when armed and healthy");
    }

    ++telemetry_sequence;
  }
}

}  // namespace

int main()
{
  run_e2e_chain();

  if (g_failures != 0) {
    std::printf("%d e2e assertion(s) failed\n", g_failures);
    return 1;
  }

  if (!write_pass_artifact(kSampleCount)) {
    return 1;
  }

  std::printf("host e2e chain passed (%zu samples @ %d ms)\n", kSampleCount,
              AUV_SCHEDULER_PERIOD_MS);
  return 0;
}
