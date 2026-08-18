# RUDDER_FAULT_MAG_SPEED_COVERAGE

**TASK_ID:** RUDDER_FAULT_MAG_SPEED_COVERAGE_001
**Date:** 2026-08-06 07:43:23
**Audit completeness:** **PASS**
**Detectability coverage:** **FAIL**
**Coverage (primary):** **FAIL**
**Fixed-horizon survivability (all 9):** **PASS**

Clean-sensor nonlinear R10 mag×speed coverage. Production cascade+guidance+plant **frozen**. B2 params **frozen** (no retune).

## Scope / sources

- Geometry: R=10.0 m, pitch_h=2.0, turns=2, T_final=45 s, λ_μw=0.25
- Certified speeds: `[1.50, 2.00] m/s` from `suite_results/SPEED_ENVELOPE_AUDIT.mat`
- Grid U = {1.5        1.75           2} m/s (subset of certified intersect)
- Grid η = {0.75         0.5        0.25} (loss 25/50/75%)
- Injection: s_half_turn=31.431838 m; δr_app=η·δr_cmd at plant-input
- Baseline reuse: `REUSED U=1.50 eta=0.50 T=45 t_f=19.60s`
- New NL 6DOF runs: 8 | Reused: 1 | Total points: 9
- Sensor: clean ASSUMED-direct IMU r + DVL u (no noise/delay in this gate)
- δe_max=15.0° δr_max=25.0°

## Frozen B2 monitor (unchanged)

| Item | Value |
|---|---:|
| G_nom [1/(m^2·rad)] | 0.851915 |
| thr_B2 [frac] | 0.277140 |
| \|δr\|_gate [deg] | 1.0 |
| u_floor [m/s] | 0.30 |
| Warmup | t > 5.0 s |
| Persistence | 0.25 s (Np=10 @ dt=0.025) |
| Retuned | NO |
| Source | `suite_results/ISOLATED_ONLINE_RUDDER_RESIDUAL_MONITOR.mat` |

## Coverage matrix (detectability)

| U\\η | η=0.75 (loss 25%) | η=0.50 (loss 50%) | η=0.25 (loss 75%) |
|---:|---:|---:|---:|
| **1.50** | **MISS** | DETECT 0.375s | DETECT 0.375s |
| **1.75** | **MISS** | DETECT 0.375s | DETECT 0.325s |
| **2.00** | DETECT 2.550s | DETECT 0.375s | DETECT 0.300s |

Coverage PASS rule: all 9 detect within 3 s with no pre-fault alarm. **No retune** to rescue misses.

## Per-point report

| U | η | loss% | reuse | t_f [s] | s_f [m] | det | delay [s] | preFA | yawMAE | CTE | pitchMAE | rollMAE | uMAE | δrSatF% | rateMax | chat | η_real | bound | prog | surv |
|---:|---:|---:|:---:|---:|---:|:---:|---:|:---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|---:|:---:|
| 1.50 | 0.75 | 25 | NO | 19.60 | 31.494 | MISS | Inf | NO | 0.175 | 0.228 | 0.041 | 1.421 | 0.348 | 0.67 | 40.0 | 37.669 | 0.750 | YES | 0.567 | PASS |
| 1.50 | 0.50 | 50 | YES | 19.60 | 31.494 | YES | 0.375 | NO | 0.187 | 0.226 | 0.041 | 1.420 | 0.348 | 0.67 | 40.0 | 37.860 | 0.500 | YES | 0.567 | PASS |
| 1.50 | 0.25 | 75 | NO | 19.60 | 31.494 | YES | 0.375 | NO | 0.306 | 0.217 | 0.041 | 1.419 | 0.348 | 0.67 | 40.0 | 38.304 | 0.250 | YES | 0.567 | PASS |
| 1.75 | 0.75 | 25 | NO | 19.45 | 31.494 | MISS | Inf | NO | 0.175 | 0.229 | 0.044 | 1.418 | 0.348 | 0.50 | 40.0 | 37.567 | 0.750 | YES | 0.569 | PASS |
| 1.75 | 0.50 | 50 | NO | 19.45 | 31.494 | YES | 0.375 | NO | 0.188 | 0.226 | 0.044 | 1.417 | 0.348 | 0.50 | 40.0 | 37.722 | 0.500 | YES | 0.569 | PASS |
| 1.75 | 0.25 | 75 | NO | 19.45 | 31.494 | YES | 0.325 | NO | 0.306 | 0.218 | 0.044 | 1.417 | 0.348 | 0.50 | 40.0 | 38.169 | 0.250 | YES | 0.569 | PASS |
| 2.00 | 0.75 | 25 | NO | 19.30 | 31.494 | YES | 2.550 | NO | 0.175 | 0.229 | 0.046 | 1.415 | 0.348 | 0.33 | 40.0 | 37.800 | 0.750 | YES | 0.571 | PASS |
| 2.00 | 0.50 | 50 | NO | 19.30 | 31.494 | YES | 0.375 | NO | 0.188 | 0.227 | 0.046 | 1.415 | 0.348 | 0.33 | 40.0 | 37.933 | 0.500 | YES | 0.571 | PASS |
| 2.00 | 0.25 | 75 | NO | 19.30 | 31.494 | YES | 0.300 | NO | 0.305 | 0.218 | 0.047 | 1.416 | 0.348 | 0.33 | 40.0 | 38.285 | 0.250 | YES | 0.571 | PASS |

### Command vs applied / pre−post (±8 s) highlights

| U | η | t_f | cmd−app postMAE [°] | pre yaw | post yaw | pre CTE | post CTE | pre δr_cmd | post δr_cmd | post δr_app |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1.50 | 0.75 | 19.60 | 1.448 | 0.176 | 0.169 | 0.385 | 0.287 | 4.342 | 5.792 | 4.344 |
| 1.50 | 0.50 | 19.60 | 4.335 | 0.176 | 0.191 | 0.385 | 0.286 | 4.342 | 8.671 | 4.335 |
| 1.50 | 0.25 | 19.60 | 12.954 | 0.176 | 0.401 | 0.385 | 0.279 | 4.342 | 17.272 | 4.318 |
| 1.75 | 0.75 | 19.45 | 1.446 | 0.178 | 0.169 | 0.384 | 0.288 | 4.330 | 5.783 | 4.338 |
| 1.75 | 0.50 | 19.45 | 4.353 | 0.178 | 0.196 | 0.384 | 0.286 | 4.330 | 8.705 | 4.353 |
| 1.75 | 0.25 | 19.45 | 12.920 | 0.178 | 0.402 | 0.384 | 0.280 | 4.330 | 17.227 | 4.307 |
| 2.00 | 0.75 | 19.30 | 1.448 | 0.179 | 0.170 | 0.384 | 0.289 | 4.348 | 5.792 | 4.344 |
| 2.00 | 0.50 | 19.30 | 4.349 | 0.179 | 0.193 | 0.384 | 0.287 | 4.348 | 8.698 | 4.349 |
| 2.00 | 0.25 | 19.30 | 12.909 | 0.179 | 0.398 | 0.384 | 0.281 | 4.348 | 17.212 | 4.303 |

## Separated verdicts

| Channel | Verdict | Rule |
|---|:---:|---|
| Audit completeness | **PASS** | all points traceable η + artifacts + envelope + frozen B2 + baseline reuse |
| Detectability coverage | **FAIL** | all 9: detect ≤3 s AND no pre-fault alarm (no retune) |
| **Coverage (primary)** | **FAIL** | ≡ detectability coverage |
| Fixed-horizon survivability | **PASS** | all 9: R10 hard ∩ T_final complete ∩ bounded ∩ no-reset (NOT mission-goal) |
| artifacts png | YES | |

### Certified demonstrated detectability region

- U=1.50/eta=0.50, U=1.50/eta=0.25, U=1.75/eta=0.50, U=1.75/eta=0.25, U=2.00/eta=0.75, U=2.00/eta=0.50, U=2.00/eta=0.25

## Next priority

- **`distinct_detector_or_actuator_feedback_requirement`** — Partial coverage — certify only demonstrated detect cells; prioritize a distinct detector / actuator-feedback requirement; do NOT retune B2.

## Files

- `run_rudder_fault_mag_speed_coverage.m` (isolated runner)
- `isolated_online_rudder_residual_monitor.m` (frozen B2 API; unchanged)
- `suite_results/RUDDER_FAULT_MAG_SPEED_COVERAGE.md`
- `suite_results/RUDDER_FAULT_MAG_SPEED_COVERAGE.mat`
- `suite_results/RUDDER_FAULT_MAG_SPEED_COVERAGE.png`
- Production: controller_law / guidance / plant **unchanged**; CODEX_VERTICAL_PLAN untouched.
