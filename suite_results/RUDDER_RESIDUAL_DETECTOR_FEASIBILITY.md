# RUDDER_RESIDUAL_DETECTOR_FEASIBILITY

**TASK_ID:** RUDDER_RESIDUAL_DETECTOR_FEASIBILITY_001
**Date:** 2026-08-06 07:11:45
**Sensor-only feasibility (B):** **PASS**
**Hardware residual (A):** **PASS_HARDWARE** (not sensor-only)

Offline study only. No new nonlinear run. Production cascade+guidance+plant **frozen**.

## Sources (3 only)

1. `suite_results/RUDDER_FAULT_BASELINE.mat`
2. `suite_results/HELIX_R10_YAW_PITCH_ENVELOPE.mat`
3. `suite_results/STATE_SPACE_MODEL_AUDIT.md` (realistic sensor definition)

## Terminology correction (prior run)

- Prior `RUDDER_FAULT_BASELINE` reached fixed `T_final=45` s with path progress **56.7%**.
- Correct term: **fixed-horizon survivability**.
- Incorrect term (avoid): mission-goal completion.
- Prior run reached fixed T_final=45s but only 56.7% path progress (s_final/s_total). Call this fixed-horizon survivability, NOT mission-goal completion.

## Realistic sensor stack (from audit)

- Refs: CTRL_OBS_AUDIT_001 / SENSOR_NOISE_CURRENT_AUDIT_001
- y_B (IMU+DVL+depth+heading): `[z φ θ ψ u v w p q r]` — IMU+DVL+depth+heading assumed direct; no absolute x,y (CTRL_OBS case B)
- y_C (+INS xy): full 12 — B + INS absolute x,y (CTRL_OBS case C)
- Production: Production feeds plant truth; realistic sensors ASSUMED only; sensor noise/delay NOT_IMPLEMENTED
- Noise: NOT_IMPLEMENTED in production stack (audit)

## Separation A vs B

| Class | Residual | Uses | Sensor-only? |
|---|---|---|:---:|
| **A** | \|δr_cmd − δr_app\| | applied rudder / effectiveness feedback | **NO** (hardware) |
| **B1** | phase-aligned \|δr_cmd − δr_nom(φ)\| | known cmd + INS xy phase | YES |
| **B2** | max(0, 1 − [r/(u²δr_cmd)]/G_nom) | known cmd + IMU r + DVL u | YES |
| **B** | B1 OR B2 | union | YES |

A is reported for comparison only and is **forbidden** as the sensor-only PASS basis.

## Equations

### A (hardware-dependent)
```
r_A(t) = |δr_cmd(t) − δr_app(t)|  [rad→deg]
Requires rudder position or effectiveness feedback (hardware).
FORBIDDEN as sensor-only feasibility evidence.
```

### B1 (command vs phase-aligned nominal demand)
```
φ(t) = unwrap(atan2(y_INS(t), x_INS(t)))
δr_nom(φ) = smooth template from nominal HELIX_R10 only
r_B1(t) = |δr_cmd(t) − δr_nom(φ(t))|  [deg]
```

### B2 (yaw-rate response / command gain)
```
G_nom = median[ r_nom / (u_nom^2 · δr_cmd_nom) ]  on gated nominal
ĝ(t) = r_IMU(t) / (max(u_DVL,u_floor)^2 · δr_cmd(t))
r_B2(t) = max(0, 1 − ĝ(t)/G_nom)   % fractional effectiveness-loss proxy
```

- Detector: alarm if residual > thr for Np=10 samples (persist=0.25s); B = B1 OR B2; thr from nominal pctl=99.0 only.
- Scaling: angles deg for B1/A; B2 dimensionless; u_floor=0.30 m/s; |δr|_gate=1.0 deg; warmup t>5.0s; G_nom frozen=0.8519 1/(m^2·rad)

## Signal provenance (B)

| Signal | Provenance |
|---|---|
| δr_cmd | known controller command log |
| r | IMU body yaw-rate (ASSUMED-direct plant truth) |
| u | DVL surge (ASSUMED-direct) |
| φ_ins | INS absolute xy → unwrap(atan2(y,x)) |
| δr_nom(φ), G_nom | frozen from HELIX_R10 nominal only |
| δr_app, η_r, fault flags | **NOT used in B** |

## Threshold / persistence selection (nominal only → frozen)

| Item | Value |
|---|---:|
| Warmup | t > 5.0 s |
| \|δr\|_gate | 1.0 deg |
| Percentile | 99.0 (raw ~1% exceedance target) |
| Persistence | 0.25 s (10 samples @ dt=0.025) |
| thr B1 [deg] | 2.1800 |
| thr B2 [frac] | 0.2771 |
| thr A [deg] | 0.25 (hardware floor) |
| G_nom | 0.8519 |
| Frozen before fault eval | YES |

## Nominal false-alarm rates

| Channel | Raw exceed % | Persisted detector % | Limit |
|---|---:|---:|---:|
| B1 | 1.000 | 0.000 | ≤1 |
| B2 | 1.003 | 0.000 | ≤1 |
| B (OR) | — | 0.000 | ≤1 |
| A | 0 (app≡cmd) | 0.000 | n/a |

## Fault detection (thresholds frozen)

| Channel | Detected | Delay [s] | Missed | Post median | Limit delay |
|---|:---:|---:|:---:|---:|---:|
| A (hw) | YES | 0.225 | NO | 4.426 deg | 3 |
| B1 | YES | 0.450 | NO | 4.457 deg | 3 |
| B2 | YES | 0.375 | NO | 0.500 | 3 |
| **B (OR)** | YES | **0.375** | NO | — | 3 |

## Gates

| Gate | Result | Detail |
|------|:------:|--------|
| A detect ≤3 s (hardware) | YES | delay=0.225 |
| B detect ≤3 s | YES | delay=0.375 |
| B nominal FA ≤1% | YES | 0.000% |
| No B data leakage | YES | app/η/labels unused in B |
| **B sensor-only feasibility** | **PASS** | — |

## Robustness limitations

- Single trajectory / single fault case: eta_r: 1→0.50 at mid-first-turn on R10@U=1.5 only
- Production sensor noise/delay NOT_IMPLEMENTED (STATE_SPACE_MODEL_AUDIT SENSOR_NOISE_CURRENT_AUDIT). Residuals use ASSUMED-direct plant truth mapped to IMU/DVL/depth/heading/INS. Noise robustness NOT certified.
- Helix phase from INS xy (atan2); template is trajectory-specific. Other paths/speeds/currents untested.
- Tracking errors stay small post-fault (controller raises δr_cmd). B1 exploits demand inflation; B2 exploits gain drop r/(u^2 δr_cmd). Pure yaw-error residual alone is weak.
- A must not be cited as sensor-only evidence.

## Next

- **`isolated_online_rudder_residual_monitor`** — B PASS → next: isolated online monitor scaffold only; production still frozen; do not promote yet.

## Files

- `run_rudder_residual_detector_feasibility.m` (isolated driver only)
- `suite_results/RUDDER_RESIDUAL_DETECTOR_FEASIBILITY.md`
- `suite_results/RUDDER_RESIDUAL_DETECTOR_FEASIBILITY.mat`
- `suite_results/RUDDER_RESIDUAL_DETECTOR_FEASIBILITY.png`
- Production: controller_law / guidance / plant **unchanged**; CODEX_VERTICAL_PLAN untouched.
