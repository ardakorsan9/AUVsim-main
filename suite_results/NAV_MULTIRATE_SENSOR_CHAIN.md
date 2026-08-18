# NAV_MULTIRATE_SENSOR_CHAIN_001 - Gate 5A multirate navigation sensor chain

**Overall verdict: PASS** - sensor-chain contract + visual QA only. **No navigation-performance claim is made.**

## Gate status and waiver

- Gate 5A begins under a **user-approved residual-risk waiver**.
- Gate 4 remains **FAIL / shadow-only** and is **not promoted** by this task.
- This is isolated downstream work only; production plant, controller and guidance are **frozen** and never called.
- CUSUM / SIL and this sensor chain remain **simulation-only**.
- `CODEX_VERTICAL_PLAN.md` **untouched** (fingerprint verified before and after: YES).

## Sources read (exactly three)

| # | Source | Used for |
|---|---|---|
| 1 | `underwater777_vehicle_dynamics_current.m` | current / ground-vs-water frame convention (markers found: nu_c=YES, nu_r=YES, ground kinematics=YES) |
| 2 | `run_sensor_noise_current_audit.m` | declared sensor/observation channel set (markers: NOT_IMPLEMENTED=YES, y_B set=YES) |
| 3 | `suite_results/SENSOR_NOISE_CURRENT_AUDIT.mat` | declared production rates and hook classification (upstream verdict PASS) |

- Declared upstream hooks: current `NOT_IMPLEMENTED`, noise `NOT_IMPLEMENTED`, delay `NOT_IMPLEMENTED`, sensor model `PRESENT_TOKEN_REVIEW`.
- Declared production rates: `dt_controller`=0.0250 s, `dt_guidance`=0.0750 s, `tau_rate`=0.0500 s, `U`=1.50 m/s.
- Reused channel set (upstream y_B): [z, phi, theta, psi, u, v, w, p, q, r] plus OPTIONAL USBL.
- Upstream declares sensor noise / delay / IMU-DVL models as NOT_IMPLEMENTED, so no sigma / bias / delay / rate can be inherited as a number. Every numeric in this chain is therefore ASSUMED, never IDENTIFIED. What IS reused: the channel set (IMU+DVL+depth+heading/INS, optional USBL), the ground-vs-water current convention, and the declared production rates.

## Current / frame convention (inherited, not re-derived)

```
nu_c_lin = R'*Vc (BODY); nu_r_lin = [u;v;w]-nu_c_lin; eta_dot = R*[u;v;w] (ground kinematics); Vc=0 reproduces production RHS
```

## ASSUMED numerics (complete list - nothing here is IDENTIFIED)

Upstream classifies sensor noise / delay / IMU-DVL models as NOT_IMPLEMENTED. Every number below is therefore **ASSUMED** and must be replaced by bench or sea-trial identification before any navigation claim.

| Channel | Quantity | Frame | Units | Rate [Hz] | Period [s] | Delay [s] | sigma | bias | scale err | q_nom | stale / dropout limit [s] | bounds | Provenance |
|---|---|---|---|---:|---:|---:|---|---|---:|---:|---|---|---|
| `imu_gyro` | angular rate | BODY | rad/s | 100 | 0.0100 | 0.005 | [0.0035 0.0035 0.0035] | [0.002 -0.0015 0.001] | 0 | 0.95 | 0.030 / 0.065 | [-10, 10] | **ASSUMED** |
| `imu_accel` | specific force | BODY | m/s^2 | 100 | 0.0100 | 0.005 | [0.02 0.02 0.02] | [0.01 -0.008 0.015] | 0 | 0.95 | 0.030 / 0.065 | [-50, 50] | **ASSUMED** |
| `dvl_vel_body_water` | water-relative velocity | BODY | m/s | 5 | 0.2000 | 0.100 | [0.01 0.01 0.015] | [0.002 -0.002 0.003] | 0.002 | 0.90 | 0.600 / 1.300 | [-10, 10] | **ASSUMED** |
| `depth_pressure` | depth | NED | m | 10 | 0.1000 | 0.020 | [0.02] | [0.05] | 0 | 0.98 | 0.270 / 0.620 | [-5, 500] | **ASSUMED** |
| `heading_compass` | heading | NED | rad | 20 | 0.0500 | 0.040 | [0.008727] | [0.01745] | 0 | 0.85 | 0.165 / 0.340 | [-3.14159, 3.14159] | **ASSUMED** |
| `ins_vel_ned` | ground velocity | NED | m/s | 50 | 0.0200 | 0.030 | [0.02 0.02 0.03] | [0.005 0.004 -0.003] | 0 | 0.92 | 0.080 / 0.150 | [-10, 10] | **ASSUMED** |
| `usbl_pos_ned` | position fix | NED | m | 0.5 | 2.0000 | 1.200 | [0.5 0.5 0.8] | [0.1 -0.1 0.2] | 0 | 0.70 | 6.200 / 13.200 | [-5000, 5000] | **ASSUMED** |

| Scenario / scheduler quantity | Value | Provenance |
|---|---:|---|
| Base scheduler tick `dt_base` | 0.0050 s | ASSUMED |
| Ground speed on path `U` | 1.50 m/s | reused declared U=1.5 |
| Gravity `g` (NED down +) | 9.81 m/s^2 | ASSUMED |
| Seabed depth (flat) | 30.0 m | ASSUMED |
| DVL bottom-lock range | [0.7, 60.0] m | ASSUMED |
| Declared DVL outage window | [0.40, 0.62] x T_final | ASSUMED |
| Quality reacquire ramp | 1.00 s | ASSUMED |
| Helix geometry R / depth gain per rev | 10.0 m / 2.0 m | ASSUMED (reused R10 family) |
| Attitude model | body x along water-relative velocity, coordinated-turn bank | ASSUMED |

## Bus definitions

### TRUTH bus (noise-free reference, never exported to a consumer)

| Field | Frame | Units | Definition |
|---|---|---|---|
| `eta_ned` | NED | m | position [x y z], z positive DOWN |
| `euler` | ZYX | rad | [phi theta psi] |
| `V_g_ned` | NED | m/s | ground velocity |
| `V_w_ned` | NED | m/s | water-relative velocity = V_g - Vc |
| `nu_body` | BODY | m/s | ground-relative body velocity = R'*V_g |
| `nu_c_body` | BODY | m/s | current in body = R'*Vc |
| `nu_r_body` | BODY | m/s | water-relative body velocity = nu - nu_c |
| `omega_body` | BODY | rad/s | [p q r] from ZYX Euler rates |
| `f_body` | BODY | m/s^2 | specific force R'*(a_ned - g_ned) |
| `altitude` | NED | m | height above ASSUMED flat seabed |
| `bottom_lock` | - | bool | DVL lock truth (range gate AND not in declared outage) |

TRUTH is a deterministic kinematic scenario generator, **not** a plant integration and **not** a controlled run. It exists only to excite the chain.

### MEASURED bus (one record per channel, per base tick)

| Field | Units | Meaning |
|---|---|---|
| `value` | channel units | last latched sample, zero-order held |
| `timestamp` | s | time the quantity was sampled (measurement time) |
| `t_rx` | s | time the sample became available = timestamp + delay |
| `sample_time` | s | nominal channel period |
| `seq` | count | message sequence, increments once per arrival |
| `seq_valid` | count | valid-update counter |
| `valid` | bool | usable this tick |
| `quality` | 0-1 | 0 on dropout, ramped after reacquire |
| `stale_age` | s | now minus timestamp of last VALID sample |
| `status` | enum | UNAVAILABLE / INIT_WAIT / OK / STALE / DROPOUT |

### ESTIMATED bus (declared, deliberately not implemented)

Gate 5A declares the ESTIMATED bus but leaves it INVALID/UNAVAILABLE. No EKF/UKF/complementary filter exists; fabricating one would be an unjustified navigation claim.

| Field | Frame | Units | Status | Value |
|---|---|---|---|---|
| `pos_ned` | NED | m | **UNAVAILABLE** | NaN (NO_ESTIMATOR_IN_GATE_5A) |
| `vel_ned` | NED | m/s | **UNAVAILABLE** | NaN (NO_ESTIMATOR_IN_GATE_5A) |
| `vel_body_water` | BODY | m/s | **UNAVAILABLE** | NaN (NO_ESTIMATOR_IN_GATE_5A) |
| `euler` | EULER | rad | **UNAVAILABLE** | NaN (NO_ESTIMATOR_IN_GATE_5A) |
| `gyro_bias` | BODY | rad/s | **UNAVAILABLE** | NaN (NO_ESTIMATOR_IN_GATE_5A) |
| `current_ned` | NED | m/s | **UNAVAILABLE** | NaN (NO_ESTIMATOR_IN_GATE_5A) |

Gate 5A verifies that this bus is invalid everywhere; it does **not** verify any estimate.

## Scheduling model

- Single base tick `dt_base` = 0.0050 s. Every channel period and every transport delay is an exact integer number of base ticks, so achieved rate can be held within one base tick by construction and is then re-measured.
- Each channel emits on its own clock, the sample enters a transport-delay queue, and the consumer latches the newest arrived sample (ZOH) until the next arrival.
- Availability is a two-stage budget per channel: OK while fresh, STALE once the held sample exceeds `stale_limit`, DROPOUT once it exceeds `dropout_limit`. A gap never overwrites `value` or `timestamp`, so the held value stays finite and bounded while `stale_age` keeps growing from the last valid sample.
- `seq` counts arrivals, so a message gap shows up as a frozen sequence counter next to a growing stale age - the pair a consumer needs to distinguish "nothing new yet" from "sensor is gone".
- Randomness comes from per-channel `RandStream` objects seeded from the case identity only (never from loop index), which is what makes reverse-order replay bitwise identical.

## Case matrix (12 cases)

Routes X / XZ / R10 at U=1.5 m/s, Vc in {0, [0 0.15 0] NED}, DVL bottom lock vs declared outage. USBL optional and ABSENT in every case.

| Case | Route | Vc [m/s NED] | DVL | T [s] | N ticks | seed | peak crab [deg] | DVL avail [%] | Result |
|---|---|---|---|---:|---:|---:|---:|---:|:---:|
| `X_Vc0_lock` | X | [0.00 0.00 0.00] | lock | 18 | 3601 | 1736306363 | 0.00 | 99.4 | PASS |
| `X_Vc0_outage` | X | [0.00 0.00 0.00] | outage | 18 | 3601 | 1719528744 | 0.00 | 78.9 | PASS |
| `X_Vc_E015_lock` | X | [0.00 0.15 0.00] | lock | 18 | 3601 | 70806246 | 5.71 | 99.4 | PASS |
| `X_Vc_E015_outage` | X | [0.00 0.15 0.00] | outage | 18 | 3601 | 54028627 | 5.71 | 78.9 | PASS |
| `XZ_Vc0_lock` | XZ | [0.00 0.00 0.00] | lock | 22 | 4401 | 637068955 | 0.00 | 99.5 | PASS |
| `XZ_Vc0_outage` | XZ | [0.00 0.00 0.00] | outage | 22 | 4401 | 620291336 | 0.00 | 78.2 | PASS |
| `XZ_Vc_E015_lock` | XZ | [0.00 0.15 0.00] | lock | 22 | 4401 | 2100020421 | 6.15 | 99.5 | PASS |
| `XZ_Vc_E015_outage` | XZ | [0.00 0.15 0.00] | outage | 22 | 4401 | 2083242802 | 6.15 | 78.2 | PASS |
| `R10_Vc0_lock` | R10 | [0.00 0.00 0.00] | lock | 45 | 9001 | 1001993762 | 0.00 | 99.8 | PASS |
| `R10_Vc0_outage` | R10 | [0.00 0.00 0.00] | outage | 45 | 9001 | 1018771381 | 0.00 | 78.2 | PASS |
| `R10_Vc_E015_lock` | R10 | [0.00 0.15 0.00] | lock | 45 | 9001 | 746023432 | 5.74 | 99.8 | PASS |
| `R10_Vc_E015_outage` | R10 | [0.00 0.15 0.00] | outage | 45 | 9001 | 762801051 | 5.74 | 78.2 | PASS |

## Achieved vs declared rates

Tolerance: one base tick (0.0050 s) on the sample period.

| Channel | Declared [Hz] | Achieved [Hz] (min over cases) | Achieved [Hz] (max over cases) | Max period error [s] | Within one tick |
|---|---:|---:|---:|---:|:---:|
| `imu_gyro` | 100 | 100.0000 | 100.0000 | 5.12e-15 | YES |
| `imu_accel` | 100 | 100.0000 | 100.0000 | 5.12e-15 | YES |
| `dvl_vel_body_water` | 5 | 5.0000 | 5.0000 | 4.27e-15 | YES |
| `depth_pressure` | 10 | 10.0000 | 10.0000 | 5.69e-15 | YES |
| `heading_compass` | 20 | 20.0000 | 20.0000 | 4.26e-15 | YES |
| `ins_vel_ned` | 50 | 50.0000 | 50.0000 | 3.98e-15 | YES |
| `usbl_pos_ned` | 0.5 (declared) | n/a ABSENT | n/a ABSENT | n/a | YES |

## Truth vs measured error (explicit, per channel)

Error is measured at the sample timestamp (delay removed), so it reflects noise + bias + scale only.

| Channel | Units | RMS min | RMS max | max abs | declared sigma | declared bias |
|---|---|---:|---:|---:|---|---|
| `imu_gyro` | rad/s | 0.0037918 | 0.0038653 | 0.017667 | [0.0035 0.0035 0.0035] | [0.002 -0.0015 0.001] |
| `imu_accel` | m/s^2 | 0.022582 | 0.023492 | 0.098148 | [0.02 0.02 0.02] | [0.01 -0.008 0.015] |
| `dvl_vel_body_water` | m/s | 0.010582 | 0.014489 | 0.050639 | [0.01 0.01 0.015] | [0.002 -0.002 0.003] |
| `depth_pressure` | m | 0.052363 | 0.055211 | 0.11147 | [0.02] | [0.05] |
| `heading_compass` | rad | 0.019086 | 0.019865 | 0.054517 | [0.008727] | [0.01745] |
| `ins_vel_ned` | m/s | 0.02403 | 0.024807 | 0.12618 | [0.02 0.02 0.03] | [0.005 0.004 -0.003] |
| `usbl_pos_ned` | m | n/a | n/a | n/a | [0.5 0.5 0.8] | [0.1 -0.1 0.2] |

No channel ever equals truth exactly (that is the no-truth-leakage gate), and the ESTIMATED bus contains only NaN.

## Frame and sign identities

| Identity | Evidence | Result |
|---|---|---|
| `nu_r = nu - R'*Vc` | max residual 4.44e-16 over all cases | YES |
| DVL is WATER-relative BODY | at Vc=0 RMS vs nu_r 0.0106-0.0136 and vs ground nu 0.0106-0.0136 m/s (identical, as required); at \|Vc\|=0.15 RMS vs nu_r 0.0115-0.0131 but vs ground nu 0.0864-0.0892 m/s | YES |
| INS is GROUND-relative NED | at Vc=0 RMS vs V_g 0.0240-0.0246 and vs V_w 0.0240-0.0246 m/s (identical); at \|Vc\|=0.15 RMS vs V_g 0.0241-0.0248 but vs V_w 0.0916-0.0924 m/s | YES |
| Depth is NED-DOWN positive | recovered bias 0.0488-0.0516 m against declared +0.050 m | YES |
| Heading is yaw, not course | peak crab 0.00-0.00 deg at Vc=0 vs 5.71-6.15 deg at \|Vc\|=0.15; heading tracks psi | YES |
| IMU reports specific force, not acceleration | mean |f_b| 9.811 m/s^2 against g=9.81 | YES |

Under Vc = 0 the water-relative and ground-relative channels coincide, exactly as the inherited convention requires; under Vc = [0 0.15 0] they separate by |Vc| = 0.15 m/s, which is what makes the frame labels falsifiable.

## Dropout / stale / quality transitions

A lost bottom lock is modelled as a **message gap** (no acoustic return means no velocity message at all), so the consumer degrades through the two-stage availability budget: OK while fresh, STALE past 0.60 s, DROPOUT past 1.30 s.

| Case | DVL stale ticks | DVL dropout ticks | STALE before DROPOUT | invalid during outage | quality 0 during outage | stale age monotonic | max stale [s] | reacquire + quality ramp |
|---|---:|---:|:---:|:---:|:---:|:---:|---:|:---:|
| `X_Vc0_lock` | 0 | 0 | n/a | n/a | n/a | n/a | 0.295 | n/a |
| `X_Vc0_outage` | 140 | 599 | YES | YES | YES | YES | 4.160 | YES |
| `X_Vc_E015_lock` | 0 | 0 | n/a | n/a | n/a | n/a | 0.295 | n/a |
| `X_Vc_E015_outage` | 140 | 599 | YES | YES | YES | YES | 4.160 | YES |
| `XZ_Vc0_lock` | 0 | 0 | n/a | n/a | n/a | n/a | 0.295 | n/a |
| `XZ_Vc0_outage` | 140 | 799 | YES | YES | YES | YES | 5.040 | YES |
| `XZ_Vc_E015_lock` | 0 | 0 | n/a | n/a | n/a | n/a | 0.295 | n/a |
| `XZ_Vc_E015_outage` | 140 | 799 | YES | YES | YES | YES | 5.040 | YES |
| `R10_Vc0_lock` | 0 | 0 | n/a | n/a | n/a | n/a | 0.295 | n/a |
| `R10_Vc0_outage` | 140 | 1799 | YES | YES | YES | YES | 10.100 | YES |
| `R10_Vc_E015_lock` | 0 | 0 | n/a | n/a | n/a | n/a | 0.295 | n/a |
| `R10_Vc_E015_outage` | 140 | 1799 | YES | YES | YES | YES | 10.100 | YES |

- Nominal (bottom-lock) cases must show **zero** stale and **zero** dropout ticks; outage cases must show the full INIT_WAIT -> OK -> STALE -> DROPOUT -> OK sequence with a quality ramp on reacquire.
- USBL is optional and ABSENT: status UNAVAILABLE, value NaN, quality 0, never valid, in every case.

## Determinism, order and reset sentinels

- Forward pass over 12 cases, then a full **reverse-order** replay: 12/12 bitwise identical (`isequaln` over value, timestamp, t_rx, seq, valid, quality, stale age and status).
- Reset sentinel, first case re-run standalone after everything else: YES.
- Reset sentinel, last case re-run standalone after everything else: YES.
- The chain module holds no `global` and no `persistent` state, so there is no path by which one case can contaminate another.

## Visual QA

- Showcase case: `R10_Vc_E015_outage` (9 panels, 260 kB).
- multirate ZOH staircase vs truth visible (DVL, depth, heading)
- status raster shows INIT_WAIT -> OK -> STALE -> DROPOUT -> OK
- stale age grows during declared outage and resets on reacquire
- quality collapses to 0 and ramps back after reacquire
- declared vs achieved rate bars agree
- USBL trace flat at zero (optional channel absent)

## PASS gates

| Gate | Result |
|---|---|
| `timing_monotonic` | PASS |
| `sequence_monotonic` | PASS |
| `rate_within_one_base_tick` | PASS |
| `frame_sign_identities` | PASS |
| `no_truth_leakage` | PASS |
| `dropout_stale_quality` | PASS |
| `finite_bounded` | PASS |
| `estimated_invalid` | PASS |
| `deterministic_replay` | PASS |
| `reset_order_sentinel` | PASS |
| `usbl_optional_absent` | PASS |
| `all_numerics_assumed` | PASS |
| `sources_exactly_three` | PASS |
| `frozen_artifacts_unchanged` | PASS |
| `visual_qa` | PASS |
| `case_matrix_complete` | PASS |

**Overall: PASS** (elapsed 26.8 s)

## Isolation evidence

| Frozen artifact | Bytes | Unchanged |
|---|---:|:---:|
| `controller_law.m` | 9402 | YES |
| `guidance_law.m` | 14601 | YES |
| `continuous_path_tracking.m` | 10845 | YES |
| `underwater777_vehicle_dynamics.m` | 6065 | YES |
| `init_parameters.m` | 4205 | YES |
| `underwater777_vehicle_dynamics_current.m` | 7814 | YES |
| `suite_results\CODEX_VERTICAL_PLAN.md` | 43101 | YES |

New files only: `navigation_multirate_sensor_chain.m`, `run_nav_multirate_sensor_chain.m`, `suite_results/NAV_MULTIRATE_SENSOR_CHAIN.{md,mat,png}`, plus appends to the readiness / realism / research logs.

## Limitations (read before using anything here)

- Every sensor number is ASSUMED. Nothing is bench-identified, so error magnitudes are illustrative only.
- TRUTH is a prescribed kinematic scenario, not a plant or closed-loop run. No tracking, stability, robustness or navigation-accuracy conclusion follows.
- There is no estimator. Availability of a MEASURED channel is not observability, and the ESTIMATED bus is INVALID by design.
- Gate 4 remains FAIL / shadow-only; nothing here promotes it. CUSUM / SIL remain simulation-only.

## Next: Gate 5B

- **`multirate_ekf_and_availability_manager`**: build the estimator on top of this frozen bus contract - multirate measurement update per channel at its own arrival time, delay compensation from the `timestamp` field, and an availability manager driven by `valid` / `quality` / `stale_age` (DVL bottom-lock loss, USBL admission when present).
- Only then may an ESTIMATED bus become VALID, and only with an explicit, separately gated navigation-accuracy claim.
- Sensor numerics must move from ASSUMED to identified before any such claim.

## MATHEMATICAL_RECORD

```
MATHEMATICAL_RECORD = {
  equations: {
    nu_c = R(phi,theta,psi)' * Vc,   nu_r = nu - nu_c,
    eta_dot = R * nu   (ground kinematics),
    f_b = R' * (a_ned - g_ned),   g_ned = [0;0;9.81],
    y_i(t_k) = h_i(x(t_k)) * (1+s_i) + b_i + sigma_i * n_i,  n_i ~ N(0,1),
    t_k = k * T_i,  arrival = t_k + tau_i,  bus = ZOH(latest arrival),
    stale_age(t) = t - timestamp(last VALID sample)
  },
  variables_units_frames: {
    eta [m] NED z-down; euler [rad] ZYX; nu, nu_r [m/s] BODY;
    omega [rad/s] BODY; f_b [m/s^2] BODY; Vc [m/s] NED;
    depth [m] NED-down positive; heading [rad] NED yaw
  },
  assumptions: {
    ALL sensor rate/sigma/bias/scale/delay/quality ASSUMED (upstream NOT_IMPLEMENTED),
    base tick 0.0050 s, flat seabed 30.0 m, DVL range [0.7, 60.0] m,
    body x along water-relative velocity with coordinated-turn bank,
    prescribed kinematic truth (no plant integration, no controller)
  },
  parameter_provenance: {
    ASSUMED: every sensor numeric, seabed, outage window, base tick,
    REUSED_DECLARED: U=1.5, dt_controller/dt_guidance/tau_rate, channel set,
    IDENTIFIED: none,
    TUNED: none
  },
  design_reason: 'Freeze a falsifiable multirate sensor bus contract before any estimator exists.',
  rejected_alternatives: {
    implement_EKF_now: rejected (would fabricate a navigation claim on ASSUMED numerics),
    feed_plant_truth_as_ESTIMATED: rejected (truth leakage),
    single_rate_sensor_model: rejected (hides delay/stale/availability semantics),
    closed_loop_run_for_truth: rejected (touches frozen production and adds no contract evidence)
  },
  evidence: { suite_results/NAV_MULTIRATE_SENSOR_CHAIN.{md,mat,png} },
  conclusion: 'PASS: all bus contracts hold across 12 deterministic cases; no navigation claim',
  open_questions: { sensor numerics remain ASSUMED; observability under DVL outage untested until Gate 5B }
}
```

## Artifacts

- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN.md`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN.mat`
- `C:\Users\ardak\MATLAB\Projects\AUVsim-main\suite_results\NAV_MULTIRATE_SENSOR_CHAIN.png`
