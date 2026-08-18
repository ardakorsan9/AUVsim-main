# HELIX_R75_YAW_PITCH_TRACK

**TASK_ID:** HELIX_R75_YAW_PITCH_TRACK_001
**Date:** 2026-08-05 20:22:16
**Verdict:** **FAIL**

Analysis/driver only. Production `controller_law` / guidance / plant / gains **unchanged**. Climb-FF already in production. X/XZ production stack untouched. No retune.

## Geometry / provenance

R75 helix = canonical suite helix with R 5.0->7.5 m only. Unchanged: pitch_h=2.0 m/turn, turns=2, n=500, T=45s, u0=1.50 m/s. Source: generate_balanced_helical_path; prior FAIL HELIX_YAW_PITCH_TRACK R=5.

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
| settling [s] | 2.40 |
| MAE / RMS / p95 [°] | 0.5559 / 0.5961 / 0.7436 |
| signed [°] | +0.5559 |

## Pitch steady (persistent)

| Metric | Value |
|--------|------:|
| MAE / RMS / p95 [°] | 0.0587 / 0.0885 / 0.1764 |
| signed / max\|e\| [°] | +0.0153 / 0.4922 |
| elev sat% | 0.00 |
| chatter [°/s] | 0.0138 |
| q RMS / ripple [°/s] | 0.3247 / 0.1177 |

## Yaw (settled_before_end)

| Metric | Value |
|--------|------:|
| MAE / RMS / p95 [°] | 0.3111 / 0.4462 / 0.6441 |
| signed / max\|e\| [°] | +0.2653 / 3.4781 |
| rudder sat% | 1.06 |
| r/(U_h κ) | 1.0240 (n_valid=1601) |
| CTE_perp sbe [m] | 0.3541 |
| radial MAE / mean [m] | 0.2012 / -0.1991 |

## PASS gates

| Gate | Result | Detail |
|------|:------:|--------|
| pitch ss MAE ≤0.30° | YES | 0.0587° |
| pitch ss p95 ≤0.50° | YES | 0.1764° |
| pitch elev sat ≤1% | YES | 0.00% |
| pitch no chatter (≤0.20 °/s) | YES | 0.0138 |
| pitch persistent settle | YES | t=2.40s |
| yaw MAE ≤1° | YES | 0.3111° |
| yaw p95 ≤2° | YES | 0.6441° |
| rudder sat ≤1% | NO | 1.06% |
| r/(U_h κ) ∈ [0.98,1.02] | NO | 1.0240 (applicable=YES) |
| no X/XZ production change | YES | driver only |

## MATHEMATICAL_DELTA

```
e_psi = wrapToPi(psi_ref - psi)
e_theta = pitch_ref - theta_phys,  theta_phys = -theta_internal
e_r = hypot(x,y) - R
ratio = mean(r) / mean(U_h_guid * kappa)   [sign-normalized]
pitch_ss = persistent |e_theta|<=0.5deg to s<0.88*s_total
yaw_ss = t>=5 & s<0.88*s_total (open helix Frenet SBE)
hist_helix_R5_yaw_FAIL MAE~37.7 rudder_sat~95% (HELIX_YAW_PITCH_TRACK)
hist_R75_circle_yaw MAE~0.3065 (capsule)
```

## Classification (no controller change)

FAIL class: **yaw authority margin** (soft). Tracking/metric OK: yaw MAE=0.3111°≈R75-circle 0.3065°, p95=0.6441°; pitch strong PASS. Gates missed only by margin: rudder sat 1.06% (≤1%) and r/(U_h κ)=1.0240 (≤1.02). Not metric/window; not controller retune. Contrast R5 helix hard authority (sat~95%, MAE~38°).

## Files

- `run_helix_r75_yaw_pitch_track.m` (analysis driver only)
- `suite_results/HELIX_R75_YAW_PITCH_TRACK.md`
- `suite_results/HELIX_R75_YAW_PITCH_TRACK.mat`
- `suite_results/HELIX_R75_YAW_PITCH_TRACK.png`
