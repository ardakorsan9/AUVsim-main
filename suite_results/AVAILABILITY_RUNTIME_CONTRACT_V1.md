# AVAILABILITY_RUNTIME_CONTRACT_V1

**Source truth:** `navigation_multirate_ekf_availability.m` SHA-256 `248d723a2141ecd067b8d768549febb471d3878636622504ada261d8516b1c20`  
**Claim:** `DEPLOY_CANDIDATE / HEALTH_STATUS_ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED`

Extract the Gate 5C availability FSM into exactly three fixed-shape functions:

- `availability_codegen_init.m`: frozen FSM constants plus seven-channel presence/period/stale-limit configuration; derives `tau_fresh[i]=max(4*period[i], stale_limit[i]+period[i], 1.0)` and `config_valid`.
- `availability_codegen_reset.m`: finite explicit state, state code 0 UNINITIALIZED, all timers/counters/accept times zero, all validity flags false.
- `availability_codegen_step.m`: one incremental health-only step.

State codes are fixed: 0 UNINITIALIZED, 1 NOMINAL, 2 DEGRADED, 3 POSITION_AID_LOST, 4 RECOVERING. Channels are fixed: 1 gyro, 2 accel, 3 depth, 4 heading, 5 INS velocity, 6 DVL water-relative velocity, 7 USBL position. Required aiding channels are every present channel in 3:7. Position aids are present channels 6 and 7; INS velocity is not a position aid.

Frozen dwell constants are `T_degrade=0.50 s`, `T_lost=2.00 s`, `T_reacq=0.50 s`, `T_clear=1.00 s`, `T_settle=3.00 s`, `tol_time=1e-12`. They remain ASSUMED / NOT_CERTIFIED.

Input is fixed: `t double`, `init_done logical`, `accepted[7] logical`. On the first valid `init_done=true` sample, set state NOMINAL, record `init_time=t`, record accepted channels, and use `dt=0`. Before initialization output UNINITIALIZED. Thereafter require finite and strictly increasing time; update per-channel last-accept times from `accepted`; use `init_time` as the startup freshness reference for a channel never accepted.

Preserve Gate 5C timer and transition semantics exactly:

- position fresh: any fresh present channel in 6:7; all aid fresh: all fresh present channels in 3:7.
- if position fresh, zero loss timer and add dt to position-ok timer; otherwise add dt to loss timer and zero position-ok.
- if all aid fresh, add dt to all-ok timer and zero degrade timer; otherwise zero all-ok and add dt to degrade timer.
- NOMINAL -> DEGRADED after `T_degrade`.
- DEGRADED -> POSITION_AID_LOST after `T_lost`, else -> NOMINAL after `T_clear`.
- POSITION_AID_LOST -> RECOVERING after `T_reacq`.
- RECOVERING -> POSITION_AID_LOST after `T_lost`, else -> NOMINAL after `T_settle`.
- Timers are reset only by their own conditions, not by transitions.

Output is fixed and finite: state code, `valid`, `pos_aid_fresh`, `all_aid_fresh`, `age[7]`, `fresh[7]`, `tau_fresh[7]`, transition flag/from/to/count, `health_bits uint32`. It must also contain three compile-time-false authority flags: `accommodation_requested`, `filter_reset_requested`, `abort_requested`.

Health bits: 1 CONFIG_INVALID, 2 INPUT_NONFINITE, 4 TIME_NONINCREASING, 8 NO_REQUIRED_AID, 16 STATE_NONFINITE. Any invalid step holds the prior finite state and emits `valid=false`; a corrupt nonfinite state cold-recovers and emits bit 16. No strings, dynamic arrays/fields, cells, global/persistent state, assert/error, NaN/Inf sentinels, estimator mutation, gain/covariance change, channel reconfiguration, filter reset, abort/surface command, or actuator output.

