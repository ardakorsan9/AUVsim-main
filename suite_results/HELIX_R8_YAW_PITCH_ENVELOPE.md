# HELIX_R8_YAW_PITCH_ENVELOPE

**TASK_ID:** HELIX_R8_YAW_PITCH_ENVELOPE_001
**Date:** 2026-08-05 20:28:58
**Verdict:** **FAIL**

Analysis/driver only. Production `controller_law` / guidance / plant / gains **unchanged**. Climb-FF already in production. X/XZ production stack untouched. No retune.

## Geometry / provenance

R8 helix envelope = R75 helix with R 7.5->8.0 m only. Unchanged: pitch_h=2.0 m/turn, turns=2, n=500, T=45s, u0=1.50 m/s. Source: generate_balanced_helical_path; prior soft FAIL HELIX_R75_YAW_PITCH_TRACK (rudder sat 1.06% / ratio 1.024). Controllers frozen.

- Frames: NED; internal `theta` negated → physical `theta_phys=-theta`.
- `e_psi = wrapToPi(psi_ref - psi)` [rad→deg for report].
- `e_theta = pitch_ref - theta_phys` (physical).
- Pitch windows: `compute_pitch_window_metrics` **persistent** ±0.5° to s<0.88 s_tot.
- Path metric: Frenet `CTE_perp` settled_before_end (open helix, not closed).
- Radial: `e_r = hypot(x,y) - R` [m].
- Rate match: `r / (U_h_guid * kappa)` on yaw SBE ∩ |κ|>1e-4 ∩ U_h>0.3.
- Rudder sat: acq=`mask_acq` (pitch window); steady=`t>=5 ∩ before_end`; full=all samples; thr=0.95 δr_max.
- λ_Muw=0.25 (curved-flight production).

## Acquisition (pitch, reported separately — not a hard gate)

| Metric | Value |
|--------|------:|
| settling [s] | 2.35 |
| MAE / RMS / p95 [°] | 0.5453 / 0.5852 / 0.7299 |
| signed [°] | +0.5453 |

## Pitch steady (persistent)

| Metric | Value |
|--------|------:|
| MAE / RMS / p95 [°] | 0.0546 / 0.0872 / 0.2006 |
| signed / max\|e\| [°] | +0.0050 / 0.4977 |
| elev sat% | 0.00 |
| chatter [°/s] | 0.0143 |
| q RMS / ripple [°/s] | 0.2994 / 0.1333 |

## Yaw (settled_before_end)

| Metric | Value |
|--------|------:|
| MAE / RMS / p95 [°] | 0.2467 / 0.2979 / 0.5113 |
| signed / max\|e\| [°] | +0.1858 / 0.8223 |
| rudder sat% acq / steady / full | 75.53 / 0.00 / 6.67 |
| r/(U_h κ) | 1.0236 (n_valid=1601) |
| CTE_perp sbe [m] | 0.3248 |
| radial MAE / mean [m] | 0.2009 / -0.2009 |

## PASS gates

| Gate | Result | Detail |
|------|:------:|--------|
| pitch ss MAE ≤0.30° | YES | 0.0546° |
| pitch ss p95 ≤0.50° | YES | 0.2006° |
| pitch elev sat ≤1% | YES | 0.00% |
| pitch no chatter (≤0.20 °/s) | YES | 0.0143 |
| pitch persistent settle | YES | t=2.35s |
| yaw MAE ≤1° | YES | 0.2467° |
| yaw p95 ≤2° | YES | 0.5113° |
| rudder sat steady ≤1% | YES | 0.00% |
| rudder sat full ≤1% | NO | 6.67% |
| r/(U_h κ) ∈ [0.98,1.02] | NO | 1.0236 (applicable=YES) |
| no X/XZ production change | YES | driver only |

## MATHEMATICAL_DELTA

```
e_psi = wrapToPi(psi_ref - psi)
e_theta = pitch_ref - theta_phys,  theta_phys = -theta_internal
e_r = hypot(x,y) - R
ratio = mean(r) / mean(U_h_guid * kappa)   [sign-normalized]
pitch_ss = persistent |e_theta|<=0.5deg to s<0.88*s_total
yaw_ss = t>=5 & s<0.88*s_total (open helix Frenet SBE)
rudder_sat_acq = %(|dr|>=0.95*dr_max) on pitch mask_acq
rudder_sat_steady = %(|dr|>=0.95*dr_max) on yaw_ss
rudder_sat_full = %(|dr|>=0.95*dr_max) on all samples
hist_helix_R5_yaw_FAIL MAE~37.7 rudder_sat~95% (HELIX_YAW_PITCH_TRACK)
hist_R75_soft_FAIL sat=1.06% ratio=1.024 (HELIX_R75_YAW_PITCH_TRACK)
```

## Classification (no controller change)

FAIL class: **yaw authority/envelope** (soft). Tracking OK if e_psi small; missed sat and/or r/(U_h κ) gates. Not metric/window; not controller retune. Pitch channel OK if pitch gates pass.

## Files

- `run_helix_r8_yaw_pitch_envelope.m` (analysis driver only)
- `suite_results/HELIX_R8_YAW_PITCH_ENVELOPE.md`
- `suite_results/HELIX_R8_YAW_PITCH_ENVELOPE.mat`
- `suite_results/HELIX_R8_YAW_PITCH_ENVELOPE.png`
