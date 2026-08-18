# AUV_RUNTIME_SUPERVISOR_CONTRACT_V1

**Claim:** `PRETARGET DEPLOY_CANDIDATE / LOGICAL COMMANDS ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED`  
**Base scheduler:** controller/FDIR/availability 40 Hz (`0.025 s`); guidance every third tick, matching its frozen `0.075 s` period. Navigation receives one fixed operation each base tick.  
**Physical boundary:** no GPIO, PWM, CAN, UART, sensor driver, actuator mapping, board pinout, calibration, flash, HIL, or physical authority is added here.

Create exactly:

- `auv_runtime_codegen_init.m`: build nested controller/guidance/navigation/availability/FDIR params and validate the frozen rate relationship.
- `auv_runtime_codegen_reset.m`: fully explicit deterministic supervisor/component state.
- `auv_runtime_codegen_step.m`: fixed-shape ordered integration and logical safety interlock.

## Init ABI

Input `cfg` contains `controller`, `guidance`, `fdir`, `availability`, and `safe_thrust`. Call the already approved component init functions. Freeze `guidance_divider=uint32(3)` and `arm_min_healthy_ticks=uint32(3)`. Require:

- finite controller/guidance timing and limits;
- `controller.dt_controller == fdir.dt == 0.025 s` within `1e-12`;
- `guidance.dt_guidance == 3*controller.dt_controller == 0.075 s` within `1e-12`;
- component `config_valid` for nav/availability/FDIR;
- `safe_thrust` finite and within controller thrust limits.

Set `params.config_valid`; do not retune any component constant.

## Reset state

Nested component states come from their reset entry points. Supervisor fields are fixed: `tick_count uint32=0`, `have_tick=false`, `last_tick_seq uint32=0`, `last_t=0`, `progress_index=1`, finite held refs (`yaw/pitch/u/r_ff/pitch_dot=0`), `guidance_ready=false`, `arm_state uint8=0`, `healthy_streak uint32=0`, `fault_bits_latched uint32=0`.

Arm states: 0 DISARMED, 1 ARMED, 2 FAULT_LATCHED. Only supervisor reset clears FAULT_LATCHED.

## Step input ABI

One fixed struct:

- `t double`, `tick_seq uint32`, `sample_valid logical`;
- `arm_request`, `disarm_request`, `kill_asserted` logical;
- `nav` exact fixed input struct for `nav_codegen_step`;
- `accepted[7] logical` for availability;
- `path_pad[96] double` (32 NED waypoints, MATLAB column-major 32x3 layout), `n_path double` integer in `[2,32]`;
- `body_rates[3] double` ordered p/q/r BODY rad/s.

The ABI contains no truth fields, route/fault labels, applied actuator values, or physical I/O handles.

## Fixed call order

1. Validate config, finite time/input/path/rates, strictly increasing `tick_seq` and `t` after the first accepted tick, and `nav.t==t` within `1e-12`.
2. Run one navigation operation. Interface admission rejects may leave the prior estimate valid; only config/math corruption and an uninitialized estimator are supervisor-critical.
3. Run availability every tick using `accepted`. Availability is status only and must never mutate estimator/controller/safety state.
4. On ticks where `mod(tick_count,3)==0`, and only with initialized finite nav plus valid path/rates, run guidance from the estimated bus: position `nav.p`, body water-relative u/v, horizontal NED speed `hypot(nav.v_N,nav.v_E)`, NED down velocity `nav.v_D`, and physical pitch `nav.euler(2)`. Store its six outputs and progress. On other ticks hold refs/progress exactly.
5. With finite held guidance refs and initialized nav, run controller every tick. Build its measured input from nav Euler/velocity and `body_rates`: p/q/r; BODY heave `vel_body_water(3)`; use guidance r_ff/pitch_dot. Controller output remains a logical command.
6. Run FDIR every tick from logical rudder command, measured r, body surge, current time/sequence. Preserve its no-isolation contract: alarm is status only and cannot change an actuator command, arm state, nav, gains, or availability.
7. Evaluate the arm/safety interlock and publish output.

## Arming and safe outputs

`ready` requires valid config/input/order, initialized finite navigation, guidance ready, finite controller output, and no kill. Availability DEGRADED/POSITION_AID_LOST and FDIR anomaly are reported but do not by themselves grant or remove authority.

- DISARMED: increment consecutive `healthy_streak` while ready, else clear it. Transition to ARMED only while `arm_request=true`, `disarm_request=false`, and the streak reaches three ticks.
- ARMED: `disarm_request` transitions to DISARMED. Kill, nonfinite core data/output, nav config/math corruption, or wrapper time/sequence/input violation transitions to FAULT_LATCHED and OR-latches the fault bits.
- FAULT_LATCHED: remains latched until `auv_runtime_codegen_reset`; arm requests cannot clear it.
- In DISARMED, FAULT_LATCHED, or any non-ready tick, publish exactly `delta_r=0`, `delta_e=0`, `thrust=safe_thrust`, `command_valid=false`.
- Only ARMED+ready publishes controller values with `command_valid=true`. Clamp surfaces/thrust again to frozen controller limits as a final independent envelope.

## Runtime health bits

- 1 CONFIG_INVALID
- 2 INPUT_INVALID_OR_NONFINITE
- 4 TICK_NONINCREASING
- 8 TIME_NONINCREASING_OR_MISMATCH
- 16 PATH_INVALID
- 32 BODY_RATES_INVALID
- 64 NAV_NOT_INITIALIZED
- 128 NAV_CRITICAL
- 256 GUIDANCE_NOT_READY
- 512 CONTROLLER_NONFINITE
- 1024 KILL_ASSERTED
- 2048 FDIR_ALARM_STATUS_ONLY
- 4096 AVAILABILITY_POSITION_AID_LOST_STATUS_ONLY
- 8192 FAULT_LATCHED

Health bits 2048 and 4096 are telemetry/status only. They must never be the sole cause of command suppression or fault latching.

## Output ABI

Always finite/fixed: logical commands and `command_valid`; arm state/readiness/streak; current and latched health; tick count; held guidance refs/progress and guidance_due; nav p/v/euler/body-water velocity/valid/health; availability state/health; FDIR residual/latch/health; controller raw command; three explicit compile-time false physical authority flags `physical_io_written`, `actuator_isolated`, `abort_requested`.

No global/persistent state, strings, cells, dynamic fields/arrays, exceptions/assert/error, or NaN/Inf control sentinels.

