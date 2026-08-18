# RUDDER_FAULT_BASELINE

**TASK_ID:** RUDDER_FAULT_BASELINE_001
**Date:** 2026-08-06 06:57:09
**Audit verdict:** **PASS**
**Survivability verdict:** **PASS**

Closes rejected mission-shaper line (`GUIDANCE_TRANSITION_SHAPER` FAIL). Production cascade+guidance+plant **frozen**. Isolated driver only.

## Fault-interface audit (3 files)

Scope: `run_path_suite.m | continuous_path_tracking.m | controller_law.m (read-only; production frozen)`

| Capability | Status |
|---|---|
| Plant-input boundary | PRESENT — controls.delta_r/delta_e/thrust struct into underwater777_vehicle_dynamics |
| Controller command log | PRESENT — suite_delta_r_log / last_delta_r diagnostics |
| Rudder mag/rate limit | PRESENT — controller_law mag+rate limit on delta_r (pre-plant) |
| Fault injection API | NOT_IMPLEMENTED |
| Fault detection (FDI) | NOT_IMPLEMENTED |
| Fault isolation | NOT_IMPLEMENTED |
| Safe mode | NOT_IMPLEMENTED |
| Actuator health monitor | NOT_IMPLEMENTED |
| Effectiveness estimator | NOT_IMPLEMENTED |
| Residual detector | NOT_IMPLEMENTED |
| Abort manager | NOT_IMPLEMENTED |

## Nominal reuse

- Status: `REUSED R=10.0 u0=1.50 T=45 PASS=YES`
- Source: `suite_results/HELIX_R10_YAW_PITCH_ENVELOPE.mat`
- Compatible feasible case: R=10.0 m, U=1.50 m/s, T=45 s (HELIX_R10 PASS).

## Injection

```
s_half_turn = 0.5*sqrt((2*pi*R)^2 + pitch_h^2) = 31.431838 m
t_fault = first t with s_prog(guidance_index) >= s_half_turn  =>  t=19.6000 s, s=31.4940 m
eta_r(t) = 1                    ,  t <  t_fault
eta_r(t) = 0.50                 ,  t >= t_fault   (50% effectiveness loss)
delta_r_applied = eta_r(t) * delta_r_cmd     % plant-input boundary only
delta_r_cmd, controller_law, guidance_law, underwater777_vehicle_dynamics UNCHANGED
hidden_reset = false
```

- Realized eta_post (cmd/app ratio, |cmd|>0.5°): **0.5000** (target 0.50)

## Pre / post fault windows (±8 s)

| Window | n | t span [s] | yawMAE [°] | pitchMAE [°] | rollMAE [°] | speedMAE | CTE | cmd−app MAE [°] | δr_cmd | δr_app |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
| pre | 320 | 11.60–19.58 | 0.176 | 0.018 | 1.430 | 0.347 | 0.385 | 0.000 | 4.342 | 4.342 |
| post | 321 | 19.60–27.60 | 0.191 | 0.014 | 1.401 | 0.345 | 0.286 | 4.335 | 8.671 | 4.335 |

## Tracking / actuators (fault run)

| Channel | Metric | Value |
|---|---|---:|
| Yaw SBE | MAE / RMS / p95 [°] | 0.1874 / 0.2244 / 0.4087 |
| Yaw | CTE_perp sbe [m] | 0.2259 |
| Yaw | r/(U_h κ) | 1.0180 (n=1601) |
| Pitch ss | MAE / p95 [°] | 0.0411 / 0.0989 |
| Pitch | elev sat% / chatter | 0.00 / 0.0127 |
| Roll SBE | MAE / p95 / |φ|_max [°] | 1.4196 / 2.0510 / 3.2808 |
| Speed | MAE_sbe / final u / [min,max] | 0.3477 / 1.547 / [1.507,1.703] |
| Rudder cmd | sat acq/ss/full % | 13.48 / 0.00 / 0.67 |
| Rudder cmd | rate max/rms [°/s] | 40.000 / 38.477 |
| Rudder cmd | chatter HF std [°/s] | 37.8604 |
| Cmd vs app | MAE full / post [°] | 2.4444 / 4.3354 |

## Mission progress / completion / bounds

| Item | Value |
|---|---:|
| s_final / s_total [m] | 71.327 / 125.724 |
| progress frac | 0.5673 |
| completed to T_final | YES |
| near_end (s≥0.88 s_tot) | NO |
| bounded | YES |
| hidden reset | NO |
| NaN count | 0 |

## Gates

| Gate | Result | Detail |
|------|:------:|--------|
| injection traceable (η≈0.50) | YES | realized=0.5000 t_f=19.60s |
| artifacts complete | YES | md/mat/png |
| **AUDIT** | **PASS** | traceable injection + artifacts |
| pitch ss MAE ≤0.30° | YES | 0.0411 |
| pitch ss p95 ≤0.50° | YES | 0.0989 |
| pitch elev sat ≤1% | YES | 0.00 |
| pitch chatter ≤0.20 | YES | 0.0127 |
| pitch persistent settle | YES | t=2.23s |
| yaw MAE ≤1° | YES | 0.1874 |
| yaw p95 ≤2° | YES | 0.4087 |
| rudder sat ss/full ≤1% | YES | 0.00 / 0.67 |
| r/(U_h κ) ∈[0.98,1.02] | YES | 1.0180 |
| completion / bounds / no-reset | YES | YES / YES / YES |
| **SURVIVABILITY** | **PASS** | R10 hard ∩ completion ∩ bounds ∩ no-reset |

## Fault signature / next priority

- Δyaw MAE (post−pre)=0.015° | ΔCTE=-0.099 m | Δ(cmd−app)=4.335°
- Signature measurable: **YES** (post−pre (±8s): cmd−app MAE, yaw MAE, or CTE jump)
- Next priority: **`residual_detector_feasibility`**

## Files

- `run_rudder_fault_baseline.m` (isolated driver only)
- `suite_results/RUDDER_FAULT_BASELINE.md`
- `suite_results/RUDDER_FAULT_BASELINE.mat`
- `suite_results/RUDDER_FAULT_BASELINE.png`
- Production: controller_law / guidance / plant **unchanged**; CODEX_VERTICAL_PLAN untouched.
