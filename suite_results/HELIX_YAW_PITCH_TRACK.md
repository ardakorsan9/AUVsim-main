# HELIX_YAW_PITCH_TRACK

**TASK_ID:** HELIX_YAW_PITCH_TRACK_001
**Date:** 2026-08-05 20:16:30
**Verdict:** **FAIL**

Analysis/driver only. Production `controller_law` / guidance / plant / gains **unchanged**. Climb-FF already in production. X/XZ production stack untouched.

## Geometry / provenance

Canonical suite helix R=5.0 (not R=7.5). Unchanged: pitch_h=2.0 m/turn, turns=2, n=500, T=45s, u0=1.50 m/s. Source: run_path_suite/make_scenario_helix + generate_balanced_helical_path.

- Frames: NED; internal `theta` negated → physical `theta_phys=-theta`.
- `e_psi = wrapToPi(psi_ref - psi)` [rad→deg for report].
- `e_theta = pitch_ref - theta_phys` (physical).
- Pitch windows: `compute_pitch_window_metrics` **persistent** ±0.5° to s<0.88 s_tot.
- Path metric: Frenet `CTE_perp` settled_before_end (open helix, not closed).
- Radial: `e_r = hypot(x,y) - R` [m].
- Rate match: `r / (U_h_guid * kappa)` on yaw SBE ∩ |κ|>1e-4 ∩ U_h>0.3.
- λ_Muw=0.25 (curved-flight production).

## Acquisition (pitch, reported separately — not a hard gate)

| Metric | Value |
|--------|------:|
| settling [s] | 2.85 |
| MAE / RMS / p95 [°] | 0.6381 / 0.6804 / 0.8599 |
| signed [°] | +0.6381 |

## Pitch steady (persistent)

| Metric | Value |
|--------|------:|
| MAE / RMS / p95 [°] | 0.0579 / 0.0879 / 0.1320 |
| signed / max\|e\| [°] | +0.0355 / 0.4957 |
| elev sat% | 0.00 |
| chatter [°/s] | 0.0240 |
| q RMS / ripple [°/s] | 0.3687 / 0.1264 |

## Yaw (settled_before_end)

| Metric | Value |
|--------|------:|
| MAE / RMS / p95 [°] | 37.7423 / 42.4326 / 59.3705 |
| signed / max\|e\| [°] | +37.5490 / 60.3595 |
| rudder sat% | 95.00 |
| r/(U_h κ) | 0.7970 (n_valid=1601) |
| CTE_perp sbe [m] | 1.1983 |
| radial MAE / mean [m] | 1.7597 / +1.7114 |

## PASS gates

| Gate | Result | Detail |
|------|:------:|--------|
| pitch ss MAE ≤0.30° | YES | 0.0579° |
| pitch ss p95 ≤0.50° | YES | 0.1320° |
| pitch elev sat ≤1% | YES | 0.00% |
| pitch no chatter (≤0.20 °/s) | YES | 0.0240 |
| pitch persistent settle | YES | t=2.85s |
| yaw MAE ≤1° | NO | 37.7423° |
| yaw p95 ≤2° | NO | 59.3705° |
| rudder sat ≤1% | NO | 95.00% |
| r/(U_h κ) ∈ [0.98,1.02] | NO | 0.7970 (applicable=YES) |
| no X/XZ production change | YES | driver only |

## MATHEMATICAL_DELTA

```
e_psi = wrapToPi(psi_ref - psi)
e_theta = pitch_ref - theta_phys,  theta_phys = -theta_internal
e_r = hypot(x,y) - R
ratio = mean(r) / mean(U_h_guid * kappa)   [sign-normalized]
pitch_ss = persistent |e_theta|<=0.5deg to s<0.88*s_total
yaw_ss = t>=5 & s<0.88*s_total (open helix Frenet SBE)
hist_helix_pitch_MAE ~ 0.21 deg (CODEX_VERTICAL_PLAN)
```

## Root cause (no controller change)

Canonical suite helix **R=5 @ u=1.5** is outside the feasible yaw envelope: rudder hard-saturated (~95%), `r/(U_h κ)=0.80`, outward radial bias ~+1.7 m. Matches prior YAW_START / Tur4A R=5 hard-turn finding. Pitch channel (climb-FF production) is clean and **better** than historical helix ~0.21° MAE.

## Next target

Driver-only **R=7.5 helix** (same pitch_h=2, u=1.5; do not retune gains). Optional later: R=5 speed/radius envelope. `CODEX_VERTICAL_PLAN.md` untouched.

## Files

- `run_helix_yaw_pitch_track.m` (analysis driver only)
- `suite_results/HELIX_YAW_PITCH_TRACK.md`
- `suite_results/HELIX_YAW_PITCH_TRACK.mat`
- `suite_results/HELIX_YAW_PITCH_TRACK.png`
