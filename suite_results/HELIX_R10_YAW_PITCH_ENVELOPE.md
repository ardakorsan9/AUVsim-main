# HELIX_R10_YAW_PITCH_ENVELOPE

**TASK_ID:** HELIX_R10_YAW_PITCH_ENVELOPE_001
**Date:** 2026-08-05 20:34:42
**Verdict:** **PASS**

Analysis/driver only. Production `controller_law` / guidance / plant / gains **unchanged**. Climb-FF already in production. X/XZ production stack untouched. No retune.

## Geometry / provenance

R10 helix envelope = R8 helix with R 8.0->10.0 m only. Unchanged: pitch_h=2.0 m/turn, turns=2, n=500, T=45s, u0=1.50 m/s, initial state construction. Source: generate_balanced_helical_path; prior soft FAIL HELIX_R8_YAW_PITCH_ENVELOPE (full sat 6.67% / ratio 1.0236; steady sat 0). Controllers frozen.

- Frames: NED; internal `theta` negated → physical `theta_phys=-theta`.
- `e_psi = wrapToPi(psi_ref - psi)` [rad→deg for report].
- `e_theta = pitch_ref - theta_phys` (physical).
- Pitch windows: `compute_pitch_window_metrics` **persistent** ±0.5° to s<0.88 s_tot.
- Path metric: Frenet `CTE_perp` settled_before_end (open helix, not closed).
- Radial: `e_r = hypot(x,y) - R` [m].
- Rate match: `r / (U_h_guid * kappa)` on yaw SBE ∩ |κ|>1e-4 ∩ U_h>0.3.
- Rudder sat: acq=`mask_acq` (pitch window); steady=`t>=5 ∩ before_end`; full=all samples; thr=0.95 δr_max.
- Startup diag: e0_wrap = wrapped e_ψ(t0); t_to_2deg = first time |e_ψ|≤2° persists ≥1.0 s.
- λ_Muw=0.25 (curved-flight production).

## Acquisition (pitch, reported separately — not a hard gate)

| Metric | Value |
|--------|------:|
| settling [s] | 2.23 |
| MAE / RMS / p95 [°] | 0.5243 / 0.5652 / 0.7013 |
| signed [°] | +0.5243 |

## Pitch steady (persistent)

| Metric | Value |
|--------|------:|
| MAE / RMS / p95 [°] | 0.0413 / 0.0712 / 0.1004 |
| signed / max\|e\| [°] | -0.0075 / 0.4917 |
| elev sat% | 0.00 |
| chatter [°/s] | 0.0157 |
| q RMS / ripple [°/s] | 0.2189 / 0.1345 |

## Yaw (settled_before_end)

| Metric | Value |
|--------|------:|
| MAE / RMS / p95 [°] | 0.1748 / 0.2041 / 0.3493 |
| signed / max\|e\| [°] | -0.0191 / 0.5524 |
| e0_wrap / |e0| [°] | +5.7710 / 5.7710 |
| t_to_|e_ψ|≤2° persist [s] | 3.43 |
| rudder sat% acq / steady / full | 13.48 / 0.00 / 0.67 |
| rudder sat first/last t [s] | 0.60 / 0.88 |
| sat samples in acq frac | 1.00 |
| r/(U_h κ) | 1.0181 (n_valid=1601) |
| CTE_perp sbe [m] | 0.2304 |
| radial MAE / mean [m] | 0.1723 / -0.1723 |

## PASS gates

| Gate | Result | Detail |
|------|:------:|--------|
| pitch ss MAE ≤0.30° | YES | 0.0413° |
| pitch ss p95 ≤0.50° | YES | 0.1004° |
| pitch elev sat ≤1% | YES | 0.00% |
| pitch no chatter (≤0.20 °/s) | YES | 0.0157 |
| pitch persistent settle | YES | t=2.23s |
| yaw MAE ≤1° | YES | 0.1748° |
| yaw p95 ≤2° | YES | 0.3493° |
| rudder sat steady ≤1% | YES | 0.00% |
| rudder sat full ≤1% | YES | 0.67% |
| r/(U_h κ) ∈ [0.98,1.02] | YES | 1.0181 (applicable=YES) |
| no X/XZ production change | YES | driver only |

**R_min,verified ≤ 10.0 m** (comfortable feasible envelope point; not an exact minimum search).

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
e0_wrap = wrapToPi(psi_ref(0)-psi(0))
t_to_2deg = first t with |e_psi|<=2deg for >=1.0s persistently
hist_R75 soft FAIL sat=1.06% ratio=1.024; R8 sat_full=6.67% ratio=1.0236 ss=0
hist_R10_circle prior ratio~1.018 sat0 (reference)
```

## Classification (no controller change)

PASS — comfortable feasible helix envelope at R=10.0 m; R_min,verified≤10.0 m (not exact min). Driver-only; production unchanged.

## Files

- `run_helix_r10_yaw_pitch_envelope.m` (analysis driver only)
- `suite_results/HELIX_R10_YAW_PITCH_ENVELOPE.md`
- `suite_results/HELIX_R10_YAW_PITCH_ENVELOPE.mat`
- `suite_results/HELIX_R10_YAW_PITCH_ENVELOPE.png`
